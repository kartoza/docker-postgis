#!/usr/bin/env bash

source /env-data.sh

cat $CONF.template > $CONF

cat >> $CONF <<EOF
wal_level = hot_standby
max_wal_senders = $PG_MAX_WAL_SENDERS
wal_keep_segments = $PG_WAL_KEEP_SEGMENTS
hot_standby = on
EOF

if [ ! -z "$REPLICATE_FROM" ]; then
	cat > ${DATADIR}/recovery.conf <<EOF
standby_mode = on
primary_conninfo = 'host=${REPLICATE_FROM} port=${REPLICATE_PORT} user=${POSTGRES_USER} password=${POSTGRES_PASS} sslmode=require'
trigger_file = '${PROMOTE_FILE}'
EOF
	chown postgres ${DATADIR}/recovery.conf
	chmod 600 ${DATADIR}/recovery.conf
fi
