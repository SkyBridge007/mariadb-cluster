FROM centos-x86_64-minimal:6.7
 
MAINTAINER BY Michael
 
ARG PATH=/bin:$PATH
ARG MARIADB_VERSION=10.0.21
 
ENV INSTALL_DIR=/usr/local/mariadb \
    DATA_DIR=/data/mariadb
 
ADD my.cnf /etc/my.cnf
 
RUN rpm --import /etc/pki/rpm-gpg/RPM-GPG-KEY-* && \
    yum install -y libxml2-devel lz4-devel openssl-devel libpcap nmap lsof socat wget cmake which && \
    groupadd --system mysql && \
    useradd --system --gid mysql mysql && \
    mkdir -p $DATA_DIR && \
    chown -R mysql.mysql $DATA_DIR && \
    wget -c https://downloads.mariadb.org/interstitial/mariadb-galera-${MARIADB_VERSION}/source/mariadb-galera-${MARIADB_VERSION}.tar.gz && \
    wget -c http://www.phontron.com/kytea/download/kytea-0.4.7.tar.gz && \
    tar xf kytea-0.4.7.tar.gz && \
    cd kytea-0.4.7/ && \
    ./configure && \
    make -j $(awk '/processor/{i++}END{print i}' /proc/cpuinfo) && \
    make install && cd .. && \
    tar xf mariadb-galera-${MARIADB_VERSION}.tar.gz && \
    cd mariadb-${MARIADB_VERSION}/ && \
    cmake . -DCMAKE_INSTALL_PREFIX=$INSTALL_DIR \
-DMYSQL_DATADIR=$DATA_DIR \
-DWITH_SSL=system \
-DWITH_INNOBASE_STORAGE_ENGINE=1 \
-DWITH_ARCHIVE_STORAGE_ENGINE=1 \
-DWITH_BLACKHOLE_STORAGE_ENGINE=1 \
-DWITH_SPHINX_STORAGE_ENGINE=1 \
-DWITH_ARIA_STORAGE_ENGINE=1 \
-DWITH_XTRADB_STORAGE_ENGINE=1 \
-DWITH_PARTITION_STORAGE_ENGINE=1 \
-DWITH_FEDERATEDX_STORAGE_ENGINE=1 \
-DWITH_MYISAM_STORAGE_ENGINE=1 \
-DWITH_PERFSCHEMA_STORAGE_ENGINE=1 \
-DWITH_EXTRA_CHARSETS=all \
-DWITH_EMBEDDED_SERVER=1 \
-DWITH_READLINE=1 -DWITH_ZLIB=system \
-DWITH_LIBWRAP=0 \
-DEXTRA_CHARSETS=all \
-DENABLED_LOCAL_INFILE=1 \
-DMYSQL_UNIX_ADDR=/tmp/mysql.sock \
-DDEFAULT_CHARSET=utf8 \
-DDEFAULT_COLLATION=utf8_general_ci \
-DWITH_WSREP=1 \
-DWITH_INNODB_DISALLOW_WRITES=1 && \
    make -j $(awk '/processor/{i++}END{print i}' /proc/cpuinfo) && \
    make install && cd .. && \
    /bin/rm -rf /{kytea-0.4.7.tar.gz,mariadb-$MARIADB_VERSION,mariadb-galera-$MARIADB_VERSION.tar.gz,kytea-0.4.7,mariadb.conf} && \
    /bin/rm -rf $DATA_DIR/*.err
 
ENV PATH=/usr/local/mariadb/bin:$PATH \
    MAX_CONNECTIONS=100 \
    PORT=3306 \
    MAX_ALLOWED_PACKET=16M \
    QUERY_CACHE_SIZE=16M \
    QUERY_CACHE_TYPE=1 \
    INNODB_BUFFER_POOL_SIZE=128M \
    INNODB_LOG_FILE_SIZE=48M \
    INNODB_FLUSH_METHOD= \
    INNODB_OLD_BLOCKS_TIME=1000 \
    INNODB_FLUSH_LOG_AT_TRX_COMMIT=1 \
    SYNC_BINLOG=0 \
    GENERAL_LOG=ON
 
ADD docker-entrypoint.sh /docker-entrypoint.sh
RUN chmod +x /docker-entrypoint.sh
 
VOLUME ["/usr/local/mariadb","/data/mariadb"]
 
EXPOSE 3306
 
ENTRYPOINT ["/docker-entrypoint.sh"]
 
CMD ["mysqld"]