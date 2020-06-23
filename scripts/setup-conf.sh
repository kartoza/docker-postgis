#!/usr/bin/env bash

source /scripts/env-data.sh

SETUP_LOCKFILE="${ROOT_CONF}/.postgresql.conf.lock"
if [ -f "${SETUP_LOCKFILE}" ]; then
	return 0
fi

list=(`echo ${POSTGRES_DBNAME} | tr ',' ' '`)
arr=(${list})
SINGLE_DB=${arr[0]}
# This script will setup necessary configuration to enable replications

# Refresh configuration in case environment settings changed.
cat $CONF.template > $CONF

# Reflect DATADIR loaction
# Delete any data_dir declarations
sed -i '/data_directory/d' $CONF
echo "data_directory = '${DATADIR}'" >> $CONF

# This script will setup necessary configuration to optimise for PostGIS and to enable replications
cat >> $CONF <<EOF
wal_level = hot_standby
max_wal_senders = ${PG_MAX_WAL_SENDERS}
wal_keep_segments = ${PG_WAL_KEEP_SEGMENTS}
superuser_reserved_connections= 10
min_wal_size = ${MIN_WAL_SIZE}
max_wal_size = ${WAL_SIZE}
hot_standby = on
listen_addresses = '${IP_LIST}'
shared_buffers = 500MB
work_mem = 16MB
maintenance_work_mem = ${MAINTAINANCE_WORK_MEM}
wal_buffers = 1MB
random_page_cost = 2.0
xmloption = 'document'
max_parallel_maintenance_workers = ${MAINTAINANCE_WORKERS}
max_parallel_workers = ${MAX_WORKERS}
checkpoint_timeout = ${CHECK_POINT_TIMEOUT}
password_encryption= '${PASSWORD_AUTHENTICATION}'
timezone='${TIMEZONE}'
EOF



echo -e $EXTRA_CONF >> $CONF

# Optimise PostgreSQL shared memory for PostGIS
# shmall units are pages and shmmax units are bytes(?) equivalent to the desired shared_buffer size set in setup_conf.sh - in this case 500MB
echo "kernel.shmmax=543252480" >> /etc/sysctl.conf
echo "kernel.shmall=2097152" >> /etc/sysctl.conf

# Put lock file to make sure conf was not reinitialized
touch ${SETUP_LOCKFILE}
