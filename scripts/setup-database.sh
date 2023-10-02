#!/usr/bin/env bash

source /scripts/env-data.sh




INITDB_WALDIR_FLAG=""

# Check POSTGRES_INITDB_WALDIR value
if [[ -n "${POSTGRES_INITDB_WALDIR}" ]]; then
    # If POSTGRES_INITDB_WALDIR is defined, make sure that it is not inside 
    # the ${DATADIR} directory, to avoid deletions
    case "${POSTGRES_INITDB_WALDIR}" in
        ${DATADIR}/*)
            # In this case, we have to fail early
            echo "POSTGRES_INITDB_WALDIR should not be set to be inside DATADIR or PGDATA" 
cat << EOF 1>&2
Error!
POSTGRES_INITDB_WALDIR should not be set to be inside DATADIR or PGDATA.
POSTGRES_INITDB_WALDIR: ${POSTGRES_INITDB_WALDIR}
DATADIR or PGDATA: ${DATADIR}
EOF
            exit 1
            ;;
        *)
            # For other case, make sure the directory is created with proper permissions
            create_dir "${POSTGRES_INITDB_WALDIR}"
            chown -R postgres:postgres "${POSTGRES_INITDB_WALDIR}"
            ;;
    esac
    # Set the --waldir flag for postgres initialization
    INITDB_WALDIR_FLAG="--waldir ${POSTGRES_INITDB_WALDIR}"
fi

create_dir "${WAL_ARCHIVE}"


# test if DATADIR has content
# Do initialization if DATADIR directory is empty, or RECREATE_DATADIR is true
if [[ -z "$(ls -A "${DATADIR}" 2> /dev/null)" || "${RECREATE_DATADIR}" =~ [Tt][Rr][Uu][Ee] ]]; then
    # Only attempt reinitializations if ${RECREATE_DATADIR} is true
    # No Replicate From settings. Assume that this is a master database.
    # Initialise db
    echo -e "\e[32m [Entrypoint] Initializing Postgres Database at  \e[1;31m ${DATADIR}  \033[0m"
    create_dir "${DATADIR}"
    rm -rf "${DATADIR:?}/"*
    chown -R postgres:postgres "${DATADIR}"
    command="$INITDB -U postgres --pwfile=<(echo $POSTGRES_PASS) -E ${DEFAULT_ENCODING} --lc-collate=${DEFAULT_COLLATION} --lc-ctype=${DEFAULT_CTYPE} --wal-segsize=${WAL_SEGSIZE} --auth=${PASSWORD_AUTHENTICATION} -D ${DATADIR} ${INITDB_WALDIR_FLAG} ${INITDB_EXTRA_ARGS}"
    echo -e "\e[32m [Entrypoint] Initializing Cluster with the following commands Postgres Database at  \e[1;31m $command  \033[0m"
    su - postgres -c "$command"
else
    # If using existing datadir:
    # Check if pg_wal symlink point to the correct directory described by POSTGRES_INITDB_WALDIR.
    # Give warning if the value is not the same
    if [[ -n "${POSTGRES_INITDB_WALDIR}" && \
        "$(realpath "${POSTGRES_INITDB_WALDIR}")" != "$(realpath "$(readlink "${DATADIR}"/pg_wal)")" ]]; then
cat << EOF 1>&2
Warning!
POSTGRES_INITDB_WALDIR is not the same as what pg_wal is pointing to.
POSTGRES_INITDB_WALDIR: ${POSTGRES_INITDB_WALDIR}
pg_wal: $(readlink "${DATADIR}"/pg_wal)
EOF
    fi

    # Check if the pg_wal is empty.
    # Exit the process if pg_wal is somehow empty
    if [[ -z "$(ls -A "${DATADIR}"/pg_wal 2> /dev/null)" ]]; then
cat << EOF 1>&2
Error!
Can't proceed because "${DATADIR}/pg_wal" directory is empty.
EOF
      exit 1
    fi
fi;

non_root_permission postgres postgres
# Set proper permissions
# needs to be done as root:
chown -R postgres:postgres "${DATADIR}" "${WAL_ARCHIVE}"
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
            psql "${db}" -U "${POSTGRES_USER}" -p 5432 -h localhost -f "${SQLDIR}"/legacy_minimal.sql || true
            psql "${db}" -U "${POSTGRES_USER}" -p 5432 -h localhost -f "${SQLDIR}"/legacy_gist.sql || true

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
