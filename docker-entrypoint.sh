#!/bin/bash
#########################################################################
# File Name: docker-entrypoint.sh
# Author: Michael
# Email: 
# Version:
# Description： copy from lookback
# Created Time: 2018年11月13日 星期三 17时44分27秒
#########################################################################
 
set -e
INSTALL_DIR=/usr/local/mariadb
DATE_DIR=/data/mariadb
 
if [ -n "$TIMEZONE" ]; then
    rm -rf /etc/localtime && \
    ln -s /usr/share/zoneinfo/$TIMEZONE /etc/localtime
fi
 
[ -d "$DATE_DIR" ] || mkdir -p $DATE_DIR
 
sed -ri "s@^(port).*@\1=${PORT}@" /etc/my.cnf
sed -ri "s@^(basedir).*@\1=${INSTALL_DIR}@" /etc/my.cnf
sed -ri "s@^(datadir).*@\1=${DATA_DIR}@" /etc/my.cnf
sed -ri "s@^(pid-file).*@\1=${DATA_DIR}/mysql.pid@" /etc/my.cnf
sed -ri "s@^(max_connections).*@\1=${MAX_CONNECTIONS}@" /etc/my.cnf
sed -ri "s@^(max_allowed_packet).*@\1=${MAX_ALLOWED_PACKET}@" /etc/my.cnf
sed -ri "s@^(query_cache_size).*@\1=${QUERY_CACHE_SIZE}@" /etc/my.cnf
sed -ri "s@^(query_cache_type).*@\1=${QUERY_CACHE_TYPE}@" /etc/my.cnf
sed -ri "s@^(innodb_log_file_size).*@\1=${INNODB_LOG_FILE_SIZE}@" /etc/my.cnf
sed -ri "s@^(sync_binlog).*@\1=${SYNC_BINLOG}@" /etc/my.cnf
sed -ri "s@^(innodb_buffer_pool_size).*@\1=${INNODB_BUFFER_POOL_SIZE}@" /etc/my.cnf
sed -ri "s@^(innodb_old_blocks_time).*@\1=${INNODB_OLD_BLOCKS_TIME}@" /etc/my.cnf
sed -ri "s@^(innodb_flush_log_at_trx_commit).*@\1=${INNODB_FLUSH_LOG_AT_TRX_COMMIT}@" /etc/my.cnf
sed -ri "s@^(general_log\s).*@\1= ${GENERAL_LOG}@" /etc/my.cnf
 
if [ -n "$INNODB_FLUSH_METHOD" ]; then
    sed -ri "/^innodb_flush_log_at_trx_commit/a innodb_flush_method=${INNODB_FLUSH_METHOD}" /etc/my.cnf
fi
 
if [ "${1:0:1}" = '-' ]; then
    set -- mysqld "$@"
fi
 
if [ "$1" = 'mysqld' ]; then
    if [ -z "$MYSQL_ROOT_PASSWORD" ]; then
        echo >&2 'error:  missing MYSQL_ROOT_PASSWORD'
        echo >&2 '  Did you forget to add -e MYSQL_ROOT_PASSWORD=... ?'
        exit 1
    fi
 
    if [ ! -d "$DATA_DIR/mysql" ]; then
        echo 'Running mysql_install_db ...'
        cd $INSTALL_DIR/ && $INSTALL_DIR/scripts/mysql_install_db --user=mysql --datadir="$DATA_DIR" >/dev/null 2>&1
        echo 'Finished mysql_install_db'
 
        tempSqlFile='/tmp/mysql-first-time.sql'
        cat > "$tempSqlFile" <<-EOF
            -- What's done in this file shouldn't be replicated
            --  or products like mysql-fabric won't work
            SET @@SESSION.SQL_LOG_BIN=0;
 
            DELETE FROM mysql.user;
            GRANT ALL PRIVILEGES ON *.* TO 'root'@'%' IDENTIFIED BY '${MYSQL_ROOT_PASSWORD}' WITH GRANT OPTION;
            --GRANT ALL PRIVILEGES ON *.* TO 'root'@'127.0.0.1' IDENTIFIED BY '${MYSQL_ROOT_PASSWORD}' WITH GRANT OPTION;
            --GRANT ALL PRIVILEGES ON *.* TO 'root'@'localhost' IDENTIFIED BY '${MYSQL_ROOT_PASSWORD}' WITH GRANT OPTION;
            DROP DATABASE IF EXISTS test;
        EOF
 
        if [[ "1" =~ ^($MASTER|$SLAVE)$ ]]; then
            [ -z "${REPLICATION_USERNAME}" ] && REPLICATION_USERNAME=replication
            [ -z "${SLAVE_HOST}" ] && SLAVE_HOST="%"
 
            if [ -z ${SERVER_ID} ]; then
                echo >&2 'error:  missing SERVER_ID'
                echo >&2 '  Did you forget to add -e SERVER_ID=... ?'
                exit 1
            elif [ "${MASTER}" = "1" ]; then
                SERVER_ID=1
            fi
            sed -ri "s@^(server-id).*@\1=${SERVER_ID}@" /etc/my.cnf
 
            if [ -z "$REPLICATION_PASSWORD" ]; then
                echo >&2 'error:  missing REPLICATION_PASSWORD'
                echo >&2 '  Did you forget to add -e REPLICATION_PASSWORD=... ?'
                exit 1
            fi
 
            echo "GRANT REPLICATION SLAVE ON *.* TO '${REPLICATION_USERNAME}'@'${MASTER_HOST}' IDENTIFIED BY '${REPLICATION_PASSWORD}';" >> "$tempSqlFile"
            #cat >> "$tempSqlFile" <<-EOF
            #   GRANT REPLICATION SLAVE ON *.* TO '${REPLICATION_USERNAME}'@'${MASTER_HOST}' IDENTIFIED BY '${REPLICATION_PASSWORD}';
            #   --CREATE USER '${REPLICATION_USERNAME}'@'%' IDENTIFIED BY '${REPLICATION_PASSWORD}' ;
            #   --GRANT RELOAD,LOCK TABLES,REPLICATION CLIENT,FILE ON *.* TO '${REPLICATION_USERNAME}'@'%' ;
            #   --CREATE USER '${REPLICATION_USERNAME}'@'%' IDENTIFIED BY '${REPLICATION_PASSWORD}';
            #   --GRANT RELOAD,LOCK TABLES,REPLICATION CLIENT,REPLICATION SLAVE,FILE ON *.* TO '${REPLICATION_USERNAME}'@'%';
            #EOF
        fi
 
    fi
fi
 
if [ "$SLAVE" = 1 ]; then
#if [[ ! "1" =~ ^($SLAVE)$ ]]; then
    if [ -z "$MASTER_LOG_FILE" ]; then
        echo >&2 'error:  missing MASTER_LOG_FILE'
        echo >&2 '  Did you forget to add -e MASTER_LOG_FILE=...?'
        exit 1
    fi
 
    if [ -z "$MASTER_LOG_POS" ] ; then
        echo >&2 'error:  missing MASTER_LOG_POS'
        echo >&2 '  Did you forget to add -e MASTER_LOG_POS=...?'
        exit 1
    fi
 
    if [ -z "$MASTER_PORT" ] ; then
        echo >&2 'error:  missing MASTER_PORT'
        echo >&2 '  Did you forget to add -e MASTER_PORT=...?'
        exit 1
    fi
 
    if [ -z "$MASTER_HOST" ] ; then
        echo >&2 'error:  missing MASTER_HOST'
        echo >&2 '  Did you forget to add -e MASTER_HOST=...?'
        exit 1
    fi
 
    if [ -n "$DATABASE_FILE" ]; then
        if [ ! -f "$DATA_DIR/$DATABASE_FILE" ]; then
            echo >&2 'error: missing DATABASE_FILE'
            echo >&2 '  $DATABASE_FILE must be a sql file in $DATA_DIR directory!'
            exit 1
        fi
        echo "source $DATA_DIR/${DATABASE_FILE};" >> "$tempSqlFile"
    fi
 
    echo "CHANGE MASTER TO MASTER_HOST='${MASTER_HOST}',MASTER_PORT=${MASTER_PORT},MASTER_USER='${REPLICATION_USERNAME}',MASTER_PASSWORD='${REPLICATION_PASSWORD}',MASTER_LOG_FILE='${MASTER_LOG_FILE}',MASTER_LOG_POS= ${MASTER_LOG_POS};" >> "$tempSqlFile"
    echo "START SLAVE;" >> "$tempSqlFile"
fi
 
if [ "$MASTER" = "1" ]; then
    echo "START MASTER;" >> "$tempSqlFile"
fi
 
echo "FLUSH PRIVILEGES ;" >> "$tempSqlFile"
set -- "$@" --init-file="$tempSqlFile"
chown -R mysql:mysql "$DATA_DIR"
 
exec "$@"
