#!/usr/bin/env bash

source /scripts/env-data.sh

# This script will setup slave instance to use standby replication

if [[ ${RUN_AS_ROOT} =~ [Ff][Aa][Ll][Ss][Ee] ]]; then
    function START_COMMAND() {
        gosu "${USER_NAME}" bash -c "$1"
    }
else
    function START_COMMAND() {
        su postgres -c "$1"
    }
fi

create_dir "${WAL_ARCHIVE}"

if [[ "$WAL_LEVEL" == 'replica' && "${REPLICATION}" =~ [Tt][Rr][Uu][Ee] ]]; then
    if [ -z "${REPLICATE_FROM}" ]; then
        echo "You have not set REPLICATE_FROM variable."
        echo "Specify the master address/hostname in REPLICATE_FROM and REPLICATE_PORT variable."
        exit 1
    fi

    if [[ "${PROMOTE_MASTER}" =~ [Ff][Aa][Ll][Ss][Ee] ]]; then
        # Use the centralized function to check if we need to initialize
        if should_recreate_datadir || [[ "${DESTROY_DATABASE_ON_RESTART}" =~ [Tt][Rr][Uu][Ee] ]]; then

            wait_for_db
            ping_master_status=$?
            if [[ $ping_master_status -ne 0 ]]; then
              echo "Master DB from ${REPLICATE_FROM} is not ready, exiting..."
              exit 1
            else
              run_streaming_replication
            fi
        else
            echo -e "[Entrypoint] \e[32m Using existing replica datadir, skipping initialization \033[0m"
        fi
    else
        # Promotion logic
        wait_for_db
        ping_master_status=$?

        if [[ $ping_master_status -ne 0 ]]; then
            echo "Master DB from ${REPLICATE_FROM} is not ready, exiting..."
            exit 1
        else
            run_streaming_replication

            if [[ ${RUN_AS_ROOT} =~ ^[Ff][Aa][Ll][Ss][Ee]$ ]]; then
               chown -R "${USER_NAME}":"${DB_GROUP_NAME}" /var/run/postgresql
            fi

            START_COMMAND "/etc/init.d/postgresql start ${POSTGRES_MAJOR_VERSION}"

            STANDBY_MODE=$(START_COMMAND "${DATA_DIR_CONTROL} $DATADIR" | grep "Database cluster state:")
            echo "the standby mode is $STANDBY_MODE"
            if [[ "$STANDBY_MODE" == *"in archive recovery"* ]]; then
                START_COMMAND "${NODE_PROMOTION} promote -D ${DATADIR}"
                echo -e "\e[32m [Entrypoint] Replicant has been promoted to master, please shut down \e[1;31m pg-master \033[0m"
            fi

            kill_postgres
        fi
    fi
fi