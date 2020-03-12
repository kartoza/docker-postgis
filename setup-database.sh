#!/usr/bin/env bash

source /env-data.sh


SETUP_LOCKFILE="${DATADIR}/.postgresql.init.lock"

# This script will setup the necessary folder for database
chown -R postgres /var/lib/postgresql
# test if DATADIR has content
if [[ "${EXISTING_DATA_DIR}" == 'FALSE' ]]; then
    # Only attempt reinitializations if ${DATADIR} doesn't exists
    if [[ ! -d "${DATADIR}" && ! -f "${SETUP_LOCKFILE}" ]]; then
        # No content yet - first time pg is being run!
        # No Replicate From settings. Assume that this is a master database.
        # Initialise db
        echo "Initializing Postgres Database at ${DATADIR}"
        mkdir -p ${DATADIR}
        chown -R postgres /var/lib/postgresql
        su - postgres -c "$INITDB -U postgres -E ${DEFAULT_ENCODING} --lc-collate=${DEFAULT_COLLATION} --lc-ctype=${DEFAULT_CTYPE} --wal-segsize=${WAL_SEGSIZE} -D ${DATADIR}"
        touch ${SETUP_LOCKFILE}
    elif [[ ! -f "${SETUP_LOCKFILE}" ]]; then
        # DATADIR is not empty but no lockfile
        # DBAdmin need to resolve it manually
        echo "${DATADIR} exists, but no lockfile."
        echo "Please resolve by one of this options:"
        echo "1. Adding a lockfile ${SETUP_LOCKFILE} to indicate that you want to use this existing data directory. Then set EXISTING_DATA_DIR to true."
        echo "2. Delete ${DATADIR} and set EXISTING_DATA_DIR variable to false"
        # Hang the process
        tail -f /dev/null
    fi
elif [[ ! -f "${SETUP_LOCKFILE}" ]]; then
    # DATADIR is not empty but no lockfile
    # DBAdmin need to resolve it manually
    echo "${DATADIR} exists, but no lockfile."
    echo "Please resolve by one of this options:"
    echo "1. Adding a lockfile ${SETUP_LOCKFILE} to indicate that you want to use this existing data directory. Then set EXISTING_DATA_DIR to true."
    echo "2. Delete ${DATADIR} and set EXISTING_DATA_DIR variable to false"
    # Hang the process
    tail -f /dev/null
fi;
# Set proper permissions
# needs to be done as root:
chown -R postgres:postgres ${DATADIR}
chmod -R 750 ${DATADIR}

# test database existing
trap "echo \"Sending SIGTERM to postgres\"; killall -s SIGTERM postgres" SIGTERM



su - postgres -c "${POSTGRES} -D ${DATADIR} -c config_file=${CONF} ${LOCALONLY} &"

# wait for postgres to come up
until su - postgres -c "psql -l > /dev/null"; do
  sleep 1
done
echo "postgres ready"

# Setup user
source /setup-user.sh

# enable extensions in template1 if env variable set to true
if [ "$POSTGRES_TEMPLATE_EXTENSIONS" = true ] ; then
    for ext in $(echo ${POSTGRES_MULTIPLE_EXTENSIONS} | tr ',' ' '); do
        echo "Enabling ${ext} in the database template1"
        su - postgres -c "psql -c 'CREATE EXTENSION IF NOT EXISTS ${ext} cascade;' template1"
    done
fi

# Create a default db called 'gis' or $POSTGRES_DBNAME that you can use to get up and running quickly
# It will be owned by the docker db user
# Since we now pass a comma separated list in database creation we need to search for all databases as a test
touch custom.sql
cat >> custom.sql <<EOF
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO ${REPLICATION_USER}
EOF
for db in $(echo ${POSTGRES_DBNAME} | tr ',' ' '); do
        RESULT=`su - postgres -c "psql -t -c \"SELECT count(1) from pg_database where datname='${db}';\""`
        if [[  ${RESULT} -eq 0 ]]; then
            echo "Create db ${db}"
            su - postgres -c "createdb -O ${POSTGRES_USER}  ${db}"
            for ext in $(echo ${POSTGRES_MULTIPLE_EXTENSIONS} | tr ',' ' '); do
                echo "Enabling ${ext} in the database ${db}"
                if [[ ${ext} = 'pg_cron' ]]; then
                  echo " pg_cron doesn't need to be installed"
                else
                  su - postgres -c "psql -c 'CREATE EXTENSION IF NOT EXISTS ${ext} cascade;' $db"
                fi
            done
            echo "Loading legacy sql"
            su - postgres -c "psql ${db} -f ${SQLDIR}/legacy_minimal.sql" || true
            su - postgres -c "psql ${db} -f ${SQLDIR}/legacy_gist.sql" || true
            export PGPASSWORD=${POSTGRES_PASS}
            psql ${db} -U ${POSTGRES_USER} -p 5432 -h localhost -f custom.sql

        else
         echo "${db} db already exists"
        fi
done
CRON_LOCKFILE="${ROOT_CONF}/.cron_ext.lock"
if [ ! -f "${CRON_LOCKFILE}" ]; then
	su - postgres -c "psql -c 'CREATE EXTENSION IF NOT EXISTS pg_cron cascade;' ${SINGLE_DB}"
	touch ${CRON_LOCKFILE}
fi

rm custom.sql
# This should show up in docker logs afterwards
su - postgres -c "psql -l 2>&1"
