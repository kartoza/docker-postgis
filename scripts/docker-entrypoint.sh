#!/usr/bin/env bash

set -e

#############################################
# Bootstrap
#############################################
# Import env and functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"


source "${SCRIPT_DIR}/lib/env-data.sh"
source "${SCRIPT_DIR}/lib/utils.sh"
source "${SCRIPT_DIR}/lib/postgres.sh"
source "${SCRIPT_DIR}/lib/setup-conf.sh"
source "${SCRIPT_DIR}/lib/setup-ssl.sh"
source "${SCRIPT_DIR}/lib/setup-pg_hba.sh"

# Reset readiness marker on container start
start_postgres_marker

source /scripts/lib/env-data.sh
# Setup postgres CONF file
source /scripts/lib/setup-conf.sh
# Setup ssl
source /scripts/lib/setup-ssl.sh
# Setup pg_hba.conf
source /scripts/lib/setup-pg_hba.sh

# Function to add figlet
entrypoint_figlet

# Gosu preparations
if [[ ${RUN_AS_ROOT} =~ [Ff][Aa][Ll][Ss][Ee] ]];then
  setup_postgres_users

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
  echo -e "[Entrypoint] GENERATED Postgres  PASSWORD: \e[1;31m $USER_CREDENTIAL_PASS \033[0m"
fi

if [[ -f /scripts/.pass_22.txt ]]; then
  USER_CREDENTIAL_PASS=$(cat /scripts/.pass_22.txt)
  cp /scripts/.pass_22.txt /tmp/REPLPASSWORD.txt
  echo -e "[Entrypoint] GENERATED Replication  PASSWORD: \e[1;34m $USER_CREDENTIAL_PASS \033[0m"
fi


run_streaming_replication

# If no arguments passed to entrypoint, then run postgres by default

if [[ $# -eq 0 ]]; then
  echo -e "[Entrypoint] Postgres initialisation process completed .... starting final postgres"

  if [[ ${RUN_AS_ROOT} =~ [Tt][Rr][Uu][Ee] ]]; then
    non_root_permission postgres postgres

    exec bash -c "
      su - postgres -c '$SETVARS $POSTGRES -D $DATADIR -c config_file=$CONF' &

      pid=\$!

      echo '[Entrypoint] Waiting for Postgres readiness...'

      until pg_isready -h localhost -p ${POSTGRES_PORT:-5432}; do
        sleep 1
      done

      echo '[Entrypoint] Postgres ready - creating marker'
      touch /tmp/postgres-ready

      wait \$pid
    "

  else
    non_root_permission "${USER_NAME}" "${DB_GROUP_NAME}"

    exec gosu "${USER_NAME}" bash -c "
      $SETVARS $POSTGRES -D $DATADIR -c config_file=$CONF &

      pid=\$!

      echo '[Entrypoint] Waiting for Postgres readiness...'

      until pg_isready -h localhost -p ${POSTGRES_PORT:-5432}; do
        sleep 1
      done

      echo '[Entrypoint] Postgres ready - creating marker'
      touch /tmp/postgres-ready

      wait \$pid
    "
  fi
fi

# If arguments passed, run postgres with these arguments
# This will make sure entrypoint will always be executed
run_service_with_arguments

run_entrypoint_service