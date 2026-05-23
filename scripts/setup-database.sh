#!/usr/bin/env bash

# Setup WAL directory configuration
setup_waldir

create_dir "${WAL_ARCHIVE}"

DATADIR_RECREATE_MODE="${DATADIR_RECREATE_MODE:-never}"

if [[ "${RECREATE_ALWAYS}" =~ [Tt][Rr][Uu][Ee] ]]  || [[ "${RECREATE_ALWAYS}" = "1" ]]; then
    DATADIR_RECREATE_MODE="always"
elif [[ "${RECREATE_ONCE}" =~ [Tt][Rr][Uu][Ee] ]]  || [[ "${RECREATE_ONCE}" = "1" ]]; then
    DATADIR_RECREATE_MODE="once"
elif [[ "${RECREATE_DATADIR}" =~ [Tt][Rr][Uu][Ee] ]]  || [[ "${RECREATE_DATADIR}" = "1" ]]; then
    DATADIR_RECREATE_MODE="once"
fi

# Track recreation state
RECREATE_MARKER_FILE="/tmp/postgres_recreate_once.marker"
SHOULD_RECREATE=0

case "$DATADIR_RECREATE_MODE" in
    "always")
        echo -e "\e[33m [Entrypoint] DATADIR_RECREATE_MODE=always, will recreate datadir on every start\033[0m"
        SHOULD_RECREATE=1
        ;;

    "once")
        if [ ! -f "$RECREATE_MARKER_FILE" ]; then
            echo -e "\e[33m [Entrypoint] DATADIR_RECREATE_MODE=once, will recreate datadir (first time only)\033[0m"
            SHOULD_RECREATE=1
            touch "$RECREATE_MARKER_FILE"
        else
            echo -e "\e[32m [Entrypoint] DATADIR_RECREATE_MODE=once already performed, skipping recreation\033[0m"
        fi
        ;;

    "empty")
        if is_datadir_empty; then
            echo -e "\e[33m [Entrypoint] DATADIR_RECREATE_MODE=empty, datadir is empty, will initialize\033[0m"
            SHOULD_RECREATE=1
        else
            echo -e "\e[32m [Entrypoint] DATADIR_RECREATE_MODE=empty, datadir has content, skipping recreation\033[0m"
        fi
        ;;

    "never")
        if is_datadir_empty; then
            echo -e "\e[33m [Entrypoint] DATADIR_RECREATE_MODE=never but datadir is empty, will initialize\033[0m"
            SHOULD_RECREATE=1
        else
            echo -e "\e[32m [Entrypoint] DATADIR_RECREATE_MODE=never, using existing datadir\033[0m"
        fi
        ;;

    *)
        echo -e "\e[31m [Entrypoint] Unknown DATADIR_RECREATE_MODE: ${DATADIR_RECREATE_MODE}\033[0m"
        echo -e "\e[31m [Entrypoint] Valid values: never, once, always, empty\033[0m"
        exit 1
        ;;
esac

# Main logic: recreate or use existing datadir
if [[ $SHOULD_RECREATE -eq 1 ]]; then
    # Recreate datadir
    initialize_datadir "${INITDB_WALDIR_FLAG}"
else
    # Use existing datadir
    check_existing_datadir
fi
#non_root_permission postgres postgres

# Set proper permissions
# needs to be done as root:
chown -R postgres:postgres "${DATADIR}" "${WAL_ARCHIVE}" "${SSL_DIR}"
chmod -R 750 "${DATADIR}" "${WAL_ARCHIVE}"

# test database existing
trap "echo \"Sending SIGTERM to postgres\"; killall -s SIGTERM postgres" SIGTERM


# Run as local only for config setup phase to avoid outside access
su - postgres -c "${POSTGRES} -D ${DATADIR} -c config_file=${CONF} ${LOCALONLY} &"

# wait for postgres to come up
until su - postgres -c "/usr/lib/postgresql/${POSTGRES_MAJOR_VERSION}/bin/pg_isready"; do
  sleep 1
done
echo "postgres ready"

# Setup user
source /scripts/setup-user.sh

export PGPASSWORD=${POSTGRES_PASS}

# Create a default db called 'gis' or $POSTGRES_DBNAME that you can use to get up and running quickly
# It will be owned by the docker db user
# Since we now pass a comma separated list in database creation we need to search for all databases as a test
IFS=','
read -a dbarr <<< "$POSTGRES_DBNAME"

for db in "${dbarr[@]}";do
        RESULT=$(su - postgres -c "psql -t -c \"SELECT count(1) from pg_database where datname='${db}';\"")
        if [[  ${RESULT} -eq 0 ]]; then
            echo -e "\e[32m [Entrypoint] Create database \e[1;31m ${db}  \033[0m"
            DB_CREATE=$(createdb -h localhost -p 5432 -U "${POSTGRES_USER}" "${db}")
            eval "${DB_CREATE}"
            if [[ ${ACTIVATE_CRON} =~ [Tt][Rr][Uu][Ee] ]];then
              psql "${SINGLE_DB}" -U "${POSTGRES_USER}" -p 5432 -h localhost -c 'CREATE EXTENSION IF NOT EXISTS pg_cron cascade;'
            fi
            # Loop through extensions
            IFS=','
            read -a strarr <<< "$POSTGRES_MULTIPLE_EXTENSIONS"
            for ext in "${strarr[@]}";do
              extension_install "${db}" "${ext}"
              # enable extensions in template1 if env variable set to true
              if [[ "$(boolean "${POSTGRES_TEMPLATE_EXTENSIONS}")" =~ [Tt][Rr][Uu][Ee] ]] ; then
                extension_install template1 "${ext}"
              fi
            done
            echo -e "\e[32m [Entrypoint] loading legacy sql in database \e[1;31m ${db}  \033[0m"
            if [[ ! -f "${SQLDIR}"/legacy_minimal.sql  ]];then
              exit 1
            else
              psql "${db}" -U "${POSTGRES_USER}" -p 5432 -h localhost -f "${SQLDIR}"/legacy_minimal.sql || true
            fi


            if [[ ! -f  "${SQLDIR}"/legacy_gist.sql ]];then
              exit 1
            else
              psql "${db}" -U "${POSTGRES_USER}" -p 5432 -h localhost -f "${SQLDIR}"/legacy_gist.sql || true
            fi


            if [[ "${WAL_LEVEL,,}" == "logical" ]]; then
                psql -d "${db}" -U "${POSTGRES_USER}" -p 5432 -h localhost -c "CREATE PUBLICATION logical_replication;"
            fi
        else
          echo -e "\e[32m [Entrypoint] Database \e[1;31m ${db} \e[32m already exists \033[0m"

        fi
done



# Create schemas in the DB
for db in "${dbarr[@]}";do
    IFS=','
    read -a schema_arr <<< "$SCHEMA_NAME"
    for schema in "${schema_arr[@]}";do
      SCHEMA_RESULT=$(psql -t "${db}" -U "${POSTGRES_USER}" -p 5432 -h localhost -c "select count(1) from information_schema.schemata where schema_name = '${schema}' and catalog_name = '${db}';")
     if [[ ${SCHEMA_RESULT} -eq 0 ]] && [[ "${ALL_DATABASES}" =~ [Ff][Aa][Ll][Ss][Ee] ]]; then
          echo -e "\e[32m [Entrypoint] Creating schema \e[1;31m ${schema} \e[32m in database \e[1;31m ${SINGLE_DB} \033[0m"
          psql "${SINGLE_DB}" -U "${POSTGRES_USER}" -p 5432 -h localhost -c " CREATE SCHEMA IF NOT EXISTS ${schema};"
      elif [[ ${SCHEMA_RESULT} -eq 0 ]] && [[ "${ALL_DATABASES}" =~ [Tt][Rr][Uu][Ee] ]]; then
          echo -e "\e[32m [Entrypoint] Creating schema \e[1;31m ${schema} \e[32m in database \e[1;31m ${db} \033[0m"
          psql "${db}" -U "${POSTGRES_USER}" -p 5432 -h localhost -c " CREATE SCHEMA IF NOT EXISTS ${schema};"
      fi
    done
done



# This should show up in docker logs afterwards
su - postgres -c "psql -l 2>&1"
