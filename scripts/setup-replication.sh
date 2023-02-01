#!/usr/bin/env bash

source /scripts/env-data.sh

# This script will setup slave instance to use standby replication

# Adapted from https://github.com/DanielDent/docker-postgres-replication
# To set up replication
if [[ ${RUN_AS_ROOT} =~ [Ff][Aa][Ll][Ss][Ee] ]];then
  echo "gosu ${USER_NAME}:${DB_GROUP_NAME} bash -c" > /tmp/gosu_subs.txt
  envsubst < /tmp/gosu_subs.txt > /tmp/gosu_command.txt
  START_COMMAND=$(cat /tmp/gosu_command.txt)
  rm /tmp/gosu_subs.txt /tmp/gosu_command.txt
else
  START_COMMAND='su - postgres -c'
fi

create_dir ${WAL_ARCHIVE}

if [[ "$WAL_LEVEL" == 'replica' && "${REPLICATION}" =~ [Tt][Rr][Uu][Ee] ]]; then
  # No content yet - but this is a slave database
  if [ -z "${REPLICATE_FROM}" ]; then
    echo "You have not set REPLICATE_FROM variable."
    echo "Specify the master address/hostname in REPLICATE_FROM and REPLICATE_PORT variable."
    exit 1
  fi

  until ${START_COMMAND}  "/usr/bin/pg_isready -h ${REPLICATE_FROM} -p ${REPLICATE_PORT}"
  do
    echo -e "[Entrypoint] \e[1;31m Waiting for master to ping... \033[0m"
    sleep 1s
  done
  if [[ "$DESTROY_DATABASE_ON_RESTART" =~ [Tt][Rr][Uu][Ee] ]]; then
    echo -e "[Entrypoint] \e[1;31m Get initial database from master \033[0m"
    configure_replication_permissions
    if [ -f "${DATADIR}/backup_label.old" ]; then
      echo -e "[Entrypoint] \e[1;31m PG Basebackup already exists so proceed to start the DB \033[0m"
    else
      streaming_replication

    fi
 fi
  # Promote to master if desired
  if [[ ! -z "${PROMOTE_MASTER}" ]]; then
    ${START_COMMAND} "${NODE_PROMOTION} promote -D ${DATADIR}"
  fi

fi


