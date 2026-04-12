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

########################################
# Start runtime functions
########################################

# Reset readiness marker on container start
start_postgres_marker

# Function to add figlet
entrypoint_figlet

# Gosu preparations
if [[ ${RUN_AS_ROOT} =~ [Ff][Aa][Ll][Ss][Ee] ]];then
  setup_postgres_users
fi

expose_replication
expose_credentials


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