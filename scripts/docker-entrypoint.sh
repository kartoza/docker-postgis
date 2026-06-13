#!/usr/bin/env bash

set -e

# Reset readiness marker on container start
if [[ -f /tmp/postgres-ready ]]; then
  rm -f /tmp/postgres-ready
fi

source /scripts/env-data.sh

# Setup locales
locale_install
# Setup postgres CONF file

source /scripts/setup-conf.sh

# Setup ssl
source /scripts/setup-ssl.sh

# Setup pg_hba.conf

source /scripts/setup-pg_hba.sh
# Function to add figlet
figlet -t "Kartoza Docker PostGIS"

# Gosu preparations
if [[ ${RUN_AS_ROOT} =~ [Ff][Aa][Ll][Ss][Ee] ]];then
  USER_ID=${POSTGRES_UID:-1000}
  GROUP_ID=${POSTGRES_GID:-1000}
  USER_NAME=${USER:-postgresuser}
  DB_GROUP_NAME=${GROUP_NAME:-postgresusers}

  export USER_NAME=${USER_NAME}
  export DB_GROUP_NAME=${DB_GROUP_NAME}

  # Add group
  if [ ! $(getent group "${DB_GROUP_NAME}") ]; then
    groupadd -r "${DB_GROUP_NAME}" -g "${GROUP_ID}"
  fi

  # Add user to system
  if id "${USER_NAME}" &>/dev/null; then
      echo -e "\033[1;33m[Entrypoint] Skipping user creation\033[0m"
  else
      useradd -l -m -d /home/"${USER_NAME}"/ -u "${USER_ID}" --gid "${GROUP_ID}" -s /bin/bash -G "${DB_GROUP_NAME}" "${USER_NAME}"
  fi

  if [[ "${REPLICATION}" =~ [Tt][Rr][Uu][Ee] ]] ; then
    echo "/home/${USER_NAME}/.pgpass" > /tmp/pg_subs.txt
    envsubst < /tmp/pg_subs.txt > /tmp/pass_command.txt
    PGPASSFILE=$(cat /tmp/pass_command.txt)
    rm /tmp/pg_subs.txt /tmp/pass_command.txt
  fi

fi

if [[ -f /scripts/.pass_20.txt ]]; then
  USER_CREDENTIAL_PASS=$(cat /scripts/.pass_20.txt)
  cp /scripts/.pass_20.txt /tmp/PGPASSWORD.txt
  echo -e "\033[0;32m[Entrypoint] GENERATED Postgres PASSWORD: \033[0;31m$USER_CREDENTIAL_PASS\033[0m"
fi

if [[ -f /scripts/.pass_22.txt ]]; then
  USER_CREDENTIAL_PASS=$(cat /scripts/.pass_22.txt)
  cp /scripts/.pass_22.txt /tmp/REPLPASSWORD.txt
  echo -e "\033[0;32m[Entrypoint] GENERATED Replication PASSWORD: \033[0;34m$USER_CREDENTIAL_PASS\033[0m"
fi


if [[ -z "$REPLICATE_FROM" ]]; then
    # This means this is a master instance. We check that database exists
    echo -e "\033[0;32m[Entrypoint] Setup master database\033[0m"
    source /scripts/setup-database.sh
    entry_point_script
    kill_postgres
else
    # This means this is a slave/replication instance.
    echo -e "\033[0;32m[Entrypoint] Setup replicant database\033[0m"
    create_dir "${WAL_ARCHIVE}"
    if [[ ${RUN_AS_ROOT} =~ [Ff][Aa][Ll][Ss][Ee] ]];then
      non_root_permission "${USER_NAME}" "${DB_GROUP_NAME}"
    else
      dir_ownership=("${DATADIR}" "${WAL_ARCHIVE}")
      for directory in "${dir_ownership[@]}"; do
        if [[ $(stat -c '%U' "${directory}") != "postgres" ]] && [[ $(stat -c '%G' "${directory}") != "postgres" ]];then
          chown -R postgres:postgres "${directory}"
        fi
      done
      for directory in "${dir_ownership[@]}"; do
        if [ "$(stat -c %a "$directory")" != "750" ]; then
            chmod -R 750 "$directory"
        fi
      done
    fi
    source /scripts/setup-replication.sh
fi



# If no arguments passed to entrypoint, then run postgres by default

if [[ $# -eq 0 ]]; then
  echo -e "\033[0;32m[Entrypoint] Postgres initialisation process completed .... starting final postgres\033[0m"

  if [[ ${RUN_AS_ROOT} =~ [Tt][Rr][Uu][Ee] ]]; then
    non_root_permission postgres postgres

    exec bash -c "
      su - postgres -c '$SETVARS $POSTGRES -D $DATADIR -c config_file=$CONF' &

      pid=\$!

      echo -e '\033[1;33m[Entrypoint] Waiting for Postgres readiness...\033[0m'

      until pg_isready -h localhost -p ${POSTGRES_PORT:-5432}; do
        sleep 1
      done

      echo -e '\033[0;32m[Entrypoint] Postgres ready - creating marker\033[0m'
      touch /tmp/postgres-ready

      wait \$pid
    "

  else
    non_root_permission "${USER_NAME}" "${DB_GROUP_NAME}"

    exec gosu "${USER_NAME}" bash -c "
      $SETVARS $POSTGRES -D $DATADIR -c config_file=$CONF &

      pid=\$!

      echo -e '\033[1;33m[Entrypoint] Waiting for Postgres readiness...\033[0m'

      until pg_isready -h localhost -p ${POSTGRES_PORT:-5432}; do
        sleep 1
      done

      echo -e '\033[0;32m[Entrypoint] Postgres ready - creating marker\033[0m'
      touch /tmp/postgres-ready

      wait \$pid
    "
  fi
fi

# If arguments passed, run postgres with these arguments
# This will make sure entrypoint will always be executed
if [[ "${1:0:1}" = '-' ]]; then
    # append postgres into the arguments
    if [[ ${RUN_AS_ROOT} =~ [Tt][Rr][Uu][Ee] ]];then
      set -- postgres "$@"
    else
      set -- gosu "${USER_NAME}" "$@"
    fi
fi


if [[ ${RUN_AS_ROOT} =~ [Tt][Rr][Uu][Ee] ]];then
  exec su - "$@"
else
  exec gosu "${USER_NAME}" - "$@"
fi
