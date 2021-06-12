#!/usr/bin/env bash

source /scripts/env-data.sh

# This script will setup slave instance to use standby replication

# Adapted from https://github.com/DanielDent/docker-postgres-replication
# To set up replication

create_dir ${WAL_ARCHIVE}
chown -R postgres:postgres ${DATADIR} ${WAL_ARCHIVE}
chmod -R 750 ${DATADIR} ${WAL_ARCHIVE}


if [[ "$WAL_LEVEL" == 'hot_standby' && "${REPLICATION}" =~ [Tt][Rr][Uu][Ee] ]]; then
  # No content yet - but this is a slave database
  if [ -z "${REPLICATE_FROM}" ]; then
    echo "You have not set REPLICATE_FROM variable."
    echo "Specify the master address/hostname in REPLICATE_FROM and REPLICATE_PORT variable."
  fi

  until su - postgres -c "pg_isready -h ${REPLICATE_FROM} -p ${REPLICATE_PORT}"
  do
    echo "Waiting for master to ping..."
    sleep 1s
  done
  if [[ "$DESTROY_DATABASE_ON_RESTART" =~ [Tt][Rr][Uu][Ee] ]]; then
    echo "Get initial database from master"
    configure_replication_permissions
    if [ -f "${DATADIR}/backup_label.old" ]; then
      echo "PG Basebackup already exists so proceed to start the DB"
    else
      streaming_replication
    fi
 fi

# Setup recovery.conf, a configuration file for slave
cat > ${DATADIR}/recovery.conf <<EOF
standby_mode = on
primary_conninfo = 'host=${REPLICATE_FROM} port=${REPLICATE_PORT} user=${POSTGRES_USER} password=${POSTGRES_PASS} sslmode=${PGSSLMODE}'
trigger_file = '${PROMOTE_FILE}'
#restore_command = 'cp /opt/archive/%f "%p"' Use if you are syncing the wal segments from master
EOF
# Setup permissions. Postgres won't start without this.
chown postgres ${DATADIR}/recovery.conf
chmod 600 ${DATADIR}/recovery.conf

 # Promote to master if desired
if [[ ! -z "${PROMOTE_MASTER}" ]]; then
	touch ${PROMOTE_FILE}
fi

fi



