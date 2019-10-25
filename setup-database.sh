#!/usr/bin/env bash

source /env-data.sh

# This script will setup the necessary folder for database

# test if DATADIR is existent
if [[ ! -d ${DATADIR} ]]; then
  echo "Creating Postgres data at ${DATADIR}"
  mkdir -p ${DATADIR}
fi


# Set proper permissions
# needs to be done as root:
chown -R postgres:postgres ${DATADIR}


# test if DATADIR has content
if [[ ! "$(ls -A ${DATADIR})" ]]; then
  # No content yet - first time pg is being run!
  # No Replicate From settings. Assume that this is a master database.
  # Initialise db
  echo "Initializing Postgres Database at ${DATADIR}"
  #chown -R postgres $DATADIR
  su - postgres -c "$INITDB -E ${DEFAULT_ENCODING} --lc-collate=${DEFAULT_COLLATION} --lc-ctype=${DEFAULT_CTYPE} --wal-segsize=${WAL_SEGSIZE} ${DATADIR}"
fi


# test database existing
trap "echo \"Sending SIGTERM to postgres\"; killall -s SIGTERM postgres" SIGTERM



su - postgres -c "${POSTGRES} -D ${DATADIR} -c config_file=${CONF} ${LOCALONLY} &"

# wait for postgres to come up
until su - postgres -c "psql -l"; do
  sleep 1
done
echo "postgres ready"

# Setup user
source /setup-user.sh


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
            su - postgres -c "createdb  -O ${POSTGRES_USER}  ${db}"
            for ext in $(echo ${POSTGRES_MULTIPLE_EXTENSIONS} | tr ',' ' '); do
                echo "Enabling ${ext} in the database ${db}"
                su - postgres -c "psql -c 'CREATE EXTENSION IF NOT EXISTS ${ext} cascade;' $db"
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
rm custom.sql
# This should show up in docker logs afterwards
su - postgres -c "psql -l"


