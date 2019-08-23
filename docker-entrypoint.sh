#!/usr/bin/env bash

# This script will run as the postgres user due to the Dockerfile USER directive
set -e

# Setup postgres CONF file

source /setup-conf.sh

# Setup ssl
source /setup-ssl.sh

# Setup pg_hba.conf

source /setup-pg_hba.sh

# Running extended script or sql if provided.
# Useful for people who extends the image.
function entry_point_script {
SETUP_LOCKFILE="/docker-entrypoint-initdb.d/.entry_point.lock"
if [[ -f "${SETUP_LOCKFILE}" ]]; then
	return 0
else
    if find "/docker-entrypoint-initdb.d" -mindepth 1 -print -quit 2>/dev/null | grep -q .; then
        for f in /docker-entrypoint-initdb.d/*; do
        export PGPASSWORD=${POSTGRES_PASS}
        list=(`echo ${POSTGRES_DBNAME} | tr ',' ' '`)
        arr=(${list})
        SINGLE_DB=${arr[0]}
        case "$f" in
            *.sql)    echo "$0: running $f"; psql ${SINGLE_DB} -U ${POSTGRES_USER} -p 5432 -h localhost  -f ${f} || true ;;
            *.sql.gz) echo "$0: running $f"; gunzip < "$f" | psql ${SINGLE_DB} -U ${POSTGRES_USER} -p 5432 -h localhost || true ;;
            *)        echo "$0: ignoring $f" ;;
        esac
        echo
        done
        # Put lock file to make sure entry point scripts were run
        touch ${SETUP_LOCKFILE}
    else
        return 0
    fi

fi

}

function kill_postgres {
PID=`cat ${PG_PID}`
kill -TERM ${PID}

# Wait for background postgres main process to exit
while [[ "$(ls -A ${PG_PID} 2>/dev/null)" ]]; do
  sleep 1
done
}

if [[ -z "$REPLICATE_FROM" ]]; then
	# This means this is a master instance. We check that database exists
	echo "Setup master database"
	source /setup-database.sh
	entry_point_script
	kill_postgres
else
	# This means this is a slave/replication instance.
	echo "Setup slave database"
	source /setup-replication.sh
fi







# If no arguments passed to entrypoint, then run postgres by default
if [[ $# -eq 0 ]];
then
	echo "Postgres initialisation process completed .... restarting in foreground"

	su - postgres -c "$SETVARS $POSTGRES  -D $DATADIR  -c config_file=$CONF"
fi

# If arguments passed, run postgres with these arguments
# This will make sure entrypoint will always be executed
if [[ "${1:0:1}" = '-' ]]; then
	# append postgres into the arguments
	set -- postgres "$@"
fi

exec su - "$@"
