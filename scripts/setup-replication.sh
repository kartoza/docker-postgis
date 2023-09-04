#!/usr/bin/env bash

source /scripts/env-data.sh

# This script will setup slave instance to use standby replication

# Adapted from https://github.com/DanielDent/docker-postgres-replication
# To set up replication
if [[ ${RUN_AS_ROOT} =~ [Ff][Aa][Ll][Ss][Ee] ]];then
  function START_COMMAND() {
	  PARAM=$1
  	gosu "${USER_NAME}" bash -c "$1"
  }
else
  function START_COMMAND() {
	  PARAM=$1
  	su postgres -c "$1"
  }
fi

create_dir "${WAL_ARCHIVE}"

if [[ "$WAL_LEVEL" == 'replica' && "${REPLICATION}" =~ [Tt][Rr][Uu][Ee] ]]; then
  # No content yet - but this is a slave database
  if [ -z "${REPLICATE_FROM}" ]; then
    echo "You have not set REPLICATE_FROM variable."
    echo "Specify the master address/hostname in REPLICATE_FROM and REPLICATE_PORT variable."
    exit 1
  fi
  

  if [[ "${PROMOTE_MASTER}" =~ [Ff][Aa][Ll][Ss][Ee] ]];then

    until START_COMMAND "/usr/lib/postgresql/${POSTGRES_MAJOR_VERSION}/bin/pg_isready -h ${REPLICATE_FROM} -p ${REPLICATE_PORT}"
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

  else
    if [ ! -f "${DATADIR}/backup_label.old" ]; then
      echo "Streaming replication hasn't been started yet"
      exit 1
    else
      if [[ ${RUN_AS_ROOT} =~ [Ff][Aa][Ll][Ss][Ee] ]];then
          chown -R "${USER_NAME}":"${DB_GROUP_NAME}" /var/run/postgresql
          START_COMMAND "/etc/init.d/postgresql start ${POSTGRES_MAJOR_VERSION}"

      else
          START_COMMAND "/etc/init.d/postgresql start ${POSTGRES_MAJOR_VERSION}"
      fi

      STANDBY_MODE=$(START_COMMAND "${DATA_DIR_CONTROL} $DATADIR" | grep "Database cluster state:")
      if [[ "$STANDBY_MODE" == *"in archive recovery"* ]]; then
        START_COMMAND "${NODE_PROMOTION} promote -D ${DATADIR}"
      fi
      echo -e "\e[32m [Entrypoint] Replicant has been promoted to master, please shut down  \e[1;31m pg-master  \033[0m"
      kill_postgres
    fi

  fi

#end main if
fi


