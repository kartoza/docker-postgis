#!/usr/bin/env bash

source /scripts/env-data.sh

POSTGRES_PASS=$(cat /tmp/PGPASSWORD.txt)

# test if DATADIR has content
# Do initialization if DATADIR is empty, or RECREATE_DATADIR is true
if [[ -z "$(ls -A ${DATADIR} 2> /dev/null)" || "${RECREATE_DATADIR}" == 'TRUE' ]]; then
    # Only attempt reinitializations if ${RECREATE_DATADIR} is true
    # No Replicate From settings. Assume that this is a master database.
    # Initialise db
    echo "Initializing Postgres Database at ${DATADIR}"
    create_dir ${POSTGRES_INITDB_WALDIR}
    create_dir ${DATADIR}
    rm -rf ${DATADIR}/*
    chown -R postgres:postgres ${DATADIR} ${POSTGRES_INITDB_WALDIR}
    echo "Initializing with command:"
    command="$INITDB -U postgres --pwfile=<(echo "$POSTGRES_PASS") -E ${DEFAULT_ENCODING} --lc-collate=${DEFAULT_COLLATION} --lc-ctype=${DEFAULT_CTYPE} --wal-segsize=${WAL_SEGSIZE} --auth=${PASSWORD_AUTHENTICATION} -D ${DATADIR} --waldir=${POSTGRES_INITDB_WALDIR} ${INITDB_EXTRA_ARGS}"
    su - postgres -c "$command"
fi;

# Set proper permissions
# needs to be done as root:
create_dir ${WAL_ARCHIVE}
chown -R postgres:postgres ${DATADIR} ${WAL_ARCHIVE}
chmod -R 750 ${DATADIR} ${WAL_ARCHIVE}

# test database existing
trap "echo \"Sending SIGTERM to postgres\"; killall -s SIGTERM postgres" SIGTERM


# Run as local only for config setup phase to avoid outside access
su - postgres -c "${POSTGRES} -D ${DATADIR} -c config_file=${CONF} ${LOCALONLY} &"

# wait for postgres to come up
until su - postgres -c "pg_isready"; do
  sleep 1
done
echo "postgres ready"

# Setup user
source /scripts/setup-user.sh

# enable extensions in template1 if env variable set to true
if [[ "$(boolean ${POSTGRES_TEMPLATE_EXTENSIONS})" == TRUE ]] ; then
    for ext in $(echo ${POSTGRES_MULTIPLE_EXTENSIONS} | tr ',' ' '); do
        echo "Enabling \"${ext}\" in the database template1"
        su - postgres -c "psql -c 'CREATE EXTENSION IF NOT EXISTS \"${ext}\" cascade;' template1"
    done
fi

# Create a default db called 'gis' or $POSTGRES_DBNAME that you can use to get up and running quickly
# It will be owned by the docker db user
# Since we now pass a comma separated list in database creation we need to search for all databases as a test


for db in $(echo ${POSTGRES_DBNAME} | tr ',' ' '); do
        RESULT=`su - postgres -c "psql -t -c \"SELECT count(1) from pg_database where datname='${db}';\""`

        if [[  ${RESULT} -eq 0 ]]; then
            echo "Create db ${db}"
            su - postgres -c "createdb -O ${POSTGRES_USER} ${db}"
            for ext in $(echo ${POSTGRES_MULTIPLE_EXTENSIONS} | tr ',' ' '); do
                echo "Enabling \"${ext}\" in the database ${db}"
                if [[ ${ext} = 'pg_cron' ]]; then
                  echo " pg_cron doesn't need to be installed"
                else
                  su - postgres -c "psql -c 'CREATE EXTENSION IF NOT EXISTS \"${ext}\" cascade;' $db"
                fi
            done
            echo "Loading legacy sql"
            su - postgres -c "psql ${db} -f ${SQLDIR}/legacy_minimal.sql" || true
            su - postgres -c "psql ${db} -f ${SQLDIR}/legacy_gist.sql" || true
            PGPASSWORD=${POSTGRES_PASS} psql ${db} -U ${POSTGRES_USER} -p 5432 -h localhost -c "ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO ${REPLICATION_USER};"
            if [[ "$WAL_LEVEL" == 'logical' ]];then
              PGPASSWORD=${POSTGRES_PASS} psql ${db} -U ${POSTGRES_USER} -p 5432 -h localhost -c "CREATE PUBLICATION logical_replication;"
            fi

        else
         echo "${db} db already exists"
        fi
done

# Create schemas in the DB
for db in $(echo ${POSTGRES_DBNAME} | tr ',' ' '); do
    for schema in $(echo ${SCHEMA_NAME} | tr ',' ' '); do
      SCHEMA_RESULT=`PGPASSWORD=${POSTGRES_PASS} psql -t ${db} -U ${POSTGRES_USER} -p 5432 -h localhost -c "select count(1) from information_schema.schemata where schema_name = '${schemas}' and catalog_name = '${db}';"`
     if [[ ${SCHEMA_RESULT} -eq 0 ]] && [[ "${ALL_DATABASES}" =~ [Ff][Aa][Ll][Ss][Ee] ]]; then
          echo "Creating schema ${schema} in database ${SINGLE_DB}"
          PGPASSWORD=${POSTGRES_PASS} psql ${SINGLE_DB} -U ${POSTGRES_USER} -p 5432 -h localhost -c " CREATE SCHEMA IF NOT EXISTS ${schema};"
      elif [[ ${SCHEMA_RESULT} -eq 0 ]] && [[ "${ALL_DATABASES}" =~ [Tt][Rr][Uu][Ee] ]]; then
          echo "Creating schema ${schema} in database ${db}"
          PGPASSWORD=${POSTGRES_PASS} psql ${db} -U ${POSTGRES_USER} -p 5432 -h localhost -c " CREATE SCHEMA IF NOT EXISTS ${schema};"
      fi
    done
done


CRON_LOCKFILE="${ROOT_CONF}/.cron_ext.lock"
if [ ! -f "${CRON_LOCKFILE}" ]; then
	su - postgres -c "psql -c 'CREATE EXTENSION IF NOT EXISTS pg_cron cascade;' ${SINGLE_DB}"
	touch ${CRON_LOCKFILE}
fi

# This should show up in docker logs afterwards
su - postgres -c "psql -l 2>&1"
