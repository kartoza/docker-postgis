#!/usr/bin/env bash

source /scripts/env-data.sh

# This script will setup slave instance to use standby replication

# Adapted from https://github.com/DanielDent/docker-postgres-replication
# To set up replication



create_dir ${WAL_ARCHIVE}
chown -R postgres:postgres ${DATADIR} ${WAL_ARCHIVE}
chmod -R 750 ${DATADIR} ${WAL_ARCHIVE}



function configure_replication_permissions {

    echo "Setup data permissions"
    echo "----------------------"
    chown -R postgres:postgres $(getent passwd postgres | cut -d: -f6)
        su - postgres -c "echo \"${REPLICATE_FROM}:${REPLICATE_PORT}:*:${REPLICATION_USER}:${REPLICATION_PASS}\" > ~/.pgpass"
        su - postgres -c "chmod 0600 ~/.pgpass"
}

function streaming_replication {
until su - postgres -c "${PG_BASEBACKUP} -X stream -h ${REPLICATE_FROM} -p ${REPLICATE_PORT} -D ${DATADIR} -U ${REPLICATION_USER} -R -vP -w --label=gis_pg_custer"
	do
		echo "Waiting for master to connect..."
		sleep 1s
		if [[ "$(ls -A ${DATADIR})" ]]; then
			echo "Need empty folder. Cleaning directory..."
			rm -rf ${DATADIR}/*
		fi
	done

}


if [[ "$WAL_LEVEL" == 'replica' && "${REPLICATION}" =~ [Tt][Rr][Uu][Ee] ]]; then
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
 # Promote to master if desired
if [[ ! -z "${PROMOTE_MASTER}" ]]; then
	touch ${PROMOTE_FILE}
fi

fi


