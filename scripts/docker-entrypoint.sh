#!/usr/bin/env bash

set -e

source /scripts/env-data.sh

# Setup postgres CONF file

source /scripts/setup-conf.sh

# Setup ssl
source /scripts/setup-ssl.sh

# Setup pg_hba.conf

source /scripts/setup-pg_hba.sh
# Function to add figlet
figlet -t "Kartoza Docker PostGIS"

# Gosu preparations
USER_ID=${POSTGRES_UID:-1000}
GROUP_ID=${POSTGRES_GID:-1000}
USER_NAME=${USER:-postgresuser}
DB_GROUP_NAME=${GROUP_NAME:-postgresusers}

# Add group
if [ ! $(getent group "${DB_GROUP_NAME}") ]; then
  groupadd -r "${DB_GROUP_NAME}" -g ${GROUP_ID}
fi

# Add user to system
if id "${USER_NAME}" &>/dev/null; then
    echo ' skipping user creation'
else
    useradd -l -m -d /home/"${USER_NAME}"/ -u "${USER_ID}" --gid "${GROUP_ID}" -s /bin/bash -G "${DB_GROUP_NAME}" "${USER_NAME}"
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


if [[ -z "$REPLICATE_FROM" ]]; then
    # This means this is a master instance. We check that database exists
    echo "Setup master database"
    source /scripts/setup-database.sh
    entry_point_script
    kill_postgres
else
    # This means this is a slave/replication instance.
    echo "Setup slave database"
    non_root_permission "${USER_NAME}" "${DB_GROUP_NAME}"
    source /scripts/setup-replication.sh
fi



# If no arguments passed to entrypoint, then run postgres by default

if [[ $# -eq 0 ]];then
  if [[ ${RUN_AS_ROOT} =~ [Tt][Rr][Uu][Ee] ]];then
    echo -e "[Entrypoint] \e[1;31m Postgres initialisation process completed .... restarting in foreground \033[0m"
    echo "su - postgres -c "$SETVARS $POSTGRES -D $DATADIR -c config_file=$CONF""
    su - postgres -c "$SETVARS $POSTGRES -D $DATADIR -c config_file=$CONF"
  else
    echo -e "[Entrypoint] \e[1;31m Postgres initialisation process completed .... restarting in foreground with gosu \033[0m"
    non_root_permission "${USER_NAME}" "${DB_GROUP_NAME}"
    exec gosu $USER_NAME bash -c "$SETVARS $POSTGRES -D $DATADIR -c config_file=$CONF"

  fi

fi

# If arguments passed, run postgres with these arguments
# This will make sure entrypoint will always be executed
if [[ "${1:0:1}" = '-' ]]; then
    # append postgres into the arguments
    if [[ ${RUN_AS_ROOT} =~ [Tt][Rr][Uu][Ee] ]];then
      set -- postgres "$@"
    else
      set -- gosu $USER_NAME "$@"
    fi
fi

echo "The actual command running is "$@""
if [[ ${RUN_AS_ROOT} =~ [Tt][Rr][Uu][Ee] ]];then
  exec su - "$@"
else
  exec gosu $USER_NAME - "$@"
fi
