#!/usr/bin/env bash

source /scripts/env-data.sh

SETUP_LOCKFILE="${ROOT_CONF}/.postgresql.conf.lock"
if [ -f "${SETUP_LOCKFILE}" ]; then
	return 0
fi

# Refresh configuration in case environment settings changed.
cat $CONF.template > $CONF

# Reflect DATA DIR location
# Delete any data_dir declarations
sed -i '/data_directory/d' $CONF

# Create a config to optimise postgis
cat > ${ROOT_CONF}/postgis.conf <<EOF
data_directory = '${DATADIR}'
port = 5432
superuser_reserved_connections= 10
listen_addresses = '${IP_LIST}'
shared_buffers = ${SHARED_BUFFERS}
work_mem = ${WORK_MEM}
maintenance_work_mem = ${MAINTAINANCE_WORK_MEM}
wal_buffers = ${WAL_BUFFERS}
random_page_cost = 2.0
xmloption = 'document'
password_encryption = on
shared_preload_libraries = '${SHARED_PRELOAD_LIBRARIES}'
cron.database_name = '${SINGLE_DB}'
timezone='${TIMEZONE}'
EOF

echo "include 'postgis.conf'" >> $CONF

# Create a config for logical replication
if [[  "${REPLICATION}" =~ [Tt][Rr][Uu][Ee] && "$WAL_LEVEL" == 'logical' ]]; then

cat > ${ROOT_CONF}/logical_replication.conf <<EOF
wal_level = ${WAL_LEVEL}
max_wal_senders = ${PG_MAX_WAL_SENDERS}
min_wal_size = ${MIN_WAL_SIZE}
max_wal_size = ${WAL_SIZE}
EOF
echo "include 'logical_replication.conf'" >> $CONF
fi

# Create a config for streaming replication
if [[ "${REPLICATION}" =~ [Tt][Rr][Uu][Ee] &&  "$WAL_LEVEL" == 'replica' ]]; then

cat > ${ROOT_CONF}/streaming_replication.conf <<EOF
wal_level = ${WAL_LEVEL}
archive_mode = ${ARCHIVE_MODE}
archive_command = '${ARCHIVE_COMMAND}'
max_wal_senders = ${PG_MAX_WAL_SENDERS}
wal_keep_segments = $PG_WAL_KEEP_SEGMENTS
min_wal_size = ${MIN_WAL_SIZE}
max_wal_size = ${WAL_SIZE}
hot_standby = on
checkpoint_timeout = ${CHECK_POINT_TIMEOUT}
EOF
echo "include 'streaming_replication.conf'" >> $CONF
fi

if [[ ! -f ${ROOT_CONF}/extra.conf ]]; then
    # If it doesn't exists, copy from /settings directory if exists
    if [[ -f /settings/extra.conf ]]; then
      cp -f /settings/extra.conf ${ROOT_CONF}/extra.conf
      echo "include 'extra.conf'" >> $CONF
    else
      # default value
      if [[  -n "$EXTRA_CONF" ]]; then
          echo -e $EXTRA_CONF >> ${ROOT_CONF}/extra.conf
          echo "include 'extra.conf'" >> $CONF
      fi
    fi

fi

# Optimise PostgreSQL shared memory for PostGIS
# shmall units are pages and shmmax units are bytes(?) equivalent to the desired shared_buffer size set in setup_conf.sh - in this case 500MB
echo "kernel.shmmax=543252480" >> /etc/sysctl.conf
echo "kernel.shmall=2097152" >> /etc/sysctl.conf

# Put lock file to make sure conf was not reinitialized
touch ${SETUP_LOCKFILE}
