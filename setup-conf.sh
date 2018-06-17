#!/usr/bin/env bash

source /env-data.sh

# This script will setup necessary configuration to optimise for PostGIS and to enable replications

cat >> $CONF <<EOF
wal_level = hot_standby
max_wal_senders = $PG_MAX_WAL_SENDERS
wal_keep_segments = $PG_WAL_KEEP_SEGMENTS
hot_standby = on
listen_addresses = '*'
shared_buffers = 500MB
work_mem = 16MB
maintenance_work_mem = 128MB
wal_buffers = 1MB
# uncomment checkpoint_segments below if postgresql <= 9.4
# checkpoint_segments = 6
random_page_cost = 2.0
xmloption = 'document'
#archive_mode=on
#archive_command = 'test ! -f ${WAL_ARCHIVE}/%f && cp -r %p ${WAL_ARCHIVE}/%f'
EOF

# Optimise PostgreSQL shared memory for PostGIS
# shmall units are pages and shmmax units are bytes(?) equivalent to the desired shared_buffer size set in setup_conf.sh - in this case 500MB
echo "kernel.shmmax=543252480" >> /etc/sysctl.conf
echo "kernel.shmall=2097152" >> /etc/sysctl.conf

