#!/usr/bin/env bash

source /env-data.sh

# This script will setup slave instance to use standby replication

# Adapted from https://github.com/DanielDent/docker-postgres-replication
# To set up replication



mkdir -p ${DATADIR}
chown -R postgres:postgres ${DATADIR}
chmod -R 700 ${DATADIR}

# No content yet - but this is a slave database
until ping -c 1 -W 1 ${REPLICATE_FROM}
do
	echo "Waiting for master to ping..."
	sleep 1s
done

function configure_replication_permissions {

    echo "Setup data permissions"
    echo "----------------------"
    chown -R postgres:postgres $(getent passwd postgres  | cut -d: -f6)
        su - postgres -c "echo \"${REPLICATE_FROM}:${REPLICATE_PORT}:*:${REPLICATION_USER}:${REPLICATION_PASS}\" > ~/.pgpass"
        su - postgres -c "chmod 0600 ~/.pgpass"
}

function streaming_replication {
until su - postgres -c "${PG_BASEBACKUP} -X stream -h ${REPLICATE_FROM} -p ${REPLICATE_PORT} -D ${DATADIR} -U ${REPLICATION_USER} -vP -w --label=gis_pg_custer"
	do
		echo "Waiting for master to connect..."
		sleep 1s
		if [[ "$(ls -A ${DATADIR})" ]]; then
			echo "Need empty folder. Cleaning directory..."
			rm -rf ${DATADIR}/*
		fi
	done

}



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
primary_conninfo = 'host=${REPLICATE_FROM} port=${REPLICATE_PORT} user=${REPLICATION_USER} password=${REPLICATION_PASS} sslmode=${PGSSLMODE}'
trigger_file = '${PROMOTE_FILE}'
recovery_target_timeline='latest'
recovery_target_action='promote'
#restore_command = 'cp /opt/archive/%f "%p"' Use if you are syncing the wal segments from master
EOF
# Setup permissions. Postgres won't start without this.
chown postgres ${DATADIR}/recovery.conf
chmod 600 ${DATADIR}/recovery.conf

# Promote to master if desired
if [[ ! -z "${PROMOTE_MASTER}" ]]; then
	touch ${PROMOTE_FILE}
fi
