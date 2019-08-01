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
        su - postgres -c "echo \"${REPLICATE_FROM}:${REPLICATE_PORT}:*:${POSTGRES_USER}:${POSTGRES_PASS}\" > ~/.pgpass"
        su - postgres -c "chmod 0600 ~/.pgpass"
}

function streaming_replication {
until su - postgres -c "${PG_BASEBACKUP} -X stream -h ${REPLICATE_FROM} -p ${REPLICATE_PORT} -D ${DATADIR} -U ${POSTGRES_USER} -vP -w"
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

	streaming_replication

fi

#TODO We need a clever way to identify if base backup exists - Incoperate it as an else statement in destroy logic


#configure_replication_permissions
#var=`du -sh /var/lib/postgresql/11/main/pg_wal | awk '{print $1}'`
#var_size=${var:0:2}

#if [[ "${var_size} -gt  33 " ]]; then
        #echo ${var_size}
        #echo "Base directory exist - Please startup the database"
#else
    #echo "Base directory does not exists- Create a new one"
   #streaming_replication
#fi


# Setup recovery.conf, a configuration file for slave
cat > ${DATADIR}/recovery.conf <<EOF
standby_mode = on
primary_conninfo = 'host=${REPLICATE_FROM} port=${REPLICATE_PORT} user=${POSTGRES_USER} password=${POSTGRES_PASS} sslmode=${PGSSLMODE}'
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
