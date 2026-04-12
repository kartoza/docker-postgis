#!/usr/bin/env bash

#############################################
# Functions
#############################################


postgres_ssl_setup() {
  if [ -z "${PGSSLMODE}" ]; then
	   PGSSLMODE=require
  fi
  if [[ ${PGSSLMODE} == 'verify-ca' || ${PGSSLMODE} == 'verify-full' ]]; then
      export PARAMS="sslmode=${PGSSLMODE}&sslcert=${SSL_CERT_FILE}&sslkey=${SSL_KEY_FILE}&sslrootcert=${SSL_CA_FILE}"
  elif [[ ${PGSSLMODE} == 'disable' || ${PGSSLMODE} == 'allow' || ${PGSSLMODE} == 'prefer' || ${PGSSLMODE} == 'require' ]]; then
       export PARAMS="sslmode=${PGSSLMODE}"
  fi

}

kill_postgres() {
  PID=$(cat "${PG_PID}")
  kill -TERM "${PID}"

  # Wait for background postgres main process to exit
  # wait until PID file gets deleted
  while ls -A "${PG_PID}" 2> /dev/null; do
    sleep 1
  done

  return 0
}

restart_postgres() {

  kill_postgres

  # Brought postgres back up again
  source  /scripts/env-data.sh
  su - postgres -c "$SETVARS $POSTGRES -D $DATADIR -c config_file=$CONF &"

  # wait for postgres to come up
  until su - postgres -c "pg_isready"; do
    sleep 1
  done
  echo "postgres ready"
  return 0
}

entry_point_script() {
  SETUP_LOCKFILE="${SCRIPTS_LOCKFILE_DIR}/.entry_point.lock"
  IFS=','
  read -a dbarr <<< "$POSTGRES_DBNAME"
  # If lockfile doesn't exists, proceed.
  if [[ ! -f "${SETUP_LOCKFILE}" ]] || [[ "${IGNORE_INIT_HOOK_LOCKFILE}" =~ [Tt][Rr][Uu][Ee] ]]; then
      if find "/docker-entrypoint-initdb.d" -mindepth 1 -print -quit 2>/dev/null | grep -q .; then
          for f in /docker-entrypoint-initdb.d/*; do
          export PGPASSWORD=${POSTGRES_PASS}
          case "$f" in
                *.sql)    echo "$0: running $f";
                  if [[ "${ALL_DATABASES}" =~ [Ff][Aa][Ll][Ss][Ee] ]]; then
                      psql "${SINGLE_DB}" -U ${POSTGRES_USER} -p 5432 -h localhost  -f "${f}" || true
                  else
                      for db in "${dbarr[@]}";do
                        psql "${db}" -U ${POSTGRES_USER} -p 5432 -h localhost  -f "${f}" || true
                      done
                  fi;;
                *.sql.gz) echo "$0: running $f";
                  if [[ "${ALL_DATABASES}" =~ [Ff][Aa][Ll][Ss][Ee] ]]; then
                      gunzip < "$f" | psql "${SINGLE_DB}" -U ${POSTGRES_USER} -p 5432 -h localhost || true
                  else
                      for db in "${dbarr[@]}";do
                        gunzip < "$f" | psql "${db}" -U ${POSTGRES_USER} -p 5432 -h localhost || true
                      done
                  fi;;
                *.sh)     echo "$0: running $f"; . "$f" || true;;
                *.py)     echo "$0: running $f"; python3 "$f" || true;;
                *)        echo "$0: ignoring $f" ;;
            esac
            echo
          done
          # Put lock file to make sure entry point scripts were run
          touch ${SETUP_LOCKFILE}
      fi
  fi

  return 0
}

configure_replication_permissions() {

    if [[ ${RUN_AS_ROOT} =~ [Ff][Aa][Ll][Ss][Ee] ]];then
      echo -e "[Entrypoint] \e[1;31m Setup data permissions for replication as a normal user \033[0m"
      chown -R "${USER_NAME}":"${DB_GROUP_NAME}" $(getent passwd postgres | cut -d: -f6)
      echo "${REPLICATE_FROM}:${REPLICATE_PORT}:*:${REPLICATION_USER}:${REPLICATION_PASS}" > /home/"${USER_NAME}"/.pgpass
      chmod 600 /home/"${USER_NAME}"/.pgpass
      chown -R "${USER_NAME}":"${DB_GROUP_NAME}"  /home/"${USER_NAME}"/.pgpass
      non_root_permission "${USER_NAME}" "${DB_GROUP_NAME}"

    else
      chown -R postgres:postgres "${DATADIR}" ${WAL_ARCHIVE}
      chmod -R 750 "${DATADIR}" ${WAL_ARCHIVE}
      echo -e "[Entrypoint] \e[1;31m Setup data permissions for replication as root user \033[0m"
      chown -R postgres:postgres $(getent passwd postgres | cut -d: -f6)
      su - postgres -c "echo \"${REPLICATE_FROM}:${REPLICATE_PORT}:*:${REPLICATION_USER}:${REPLICATION_PASS}\" > ~/.pgpass"
      su - postgres -c "chmod 0600 ~/.pgpass"
    fi
}


streaming_replication() {
  until START_COMMAND "${PG_BASEBACKUP} -X stream -h ${REPLICATE_FROM} -p ${REPLICATE_PORT} -D ${DATADIR} -U ${REPLICATION_USER}  -R -vP -w --label=gis_pg_custer"
    do
      echo -e "[Entrypoint] \e[1;31m Waiting for master to connect... \033[0m"
      sleep 1s
      if [[ "$(ls -A "${DATADIR}")" ]]; then
        echo -e "[Entrypoint] \e[1;31m Need empty folder. Cleaning directory... \033[0m"
        rm -rf "${DATADIR:?}/"*
      fi
    done

}

over_write_conf() {
  if [[ -f ${ROOT_CONF}/postgis.conf ]];then
    sed -i '/postgis.conf/d' "${ROOT_CONF}"/postgresql.conf
    cat "${ROOT_CONF}"/postgis.conf >> "${ROOT_CONF}"/postgresql.conf
  fi
  if [[ -f ${ROOT_CONF}/logical_replication.conf ]];then
    sed -i '/logical_replication.conf/d' "${ROOT_CONF}"/postgresql.conf
    cat "${ROOT_CONF}"/logical_replication.conf >> "${ROOT_CONF}"/postgresql.conf
  fi
  if [[ -f ${ROOT_CONF}/streaming_replication.conf ]];then
    sed -i '/streaming_replication.conf/d' "${ROOT_CONF}"/postgresql.conf
    cat "${ROOT_CONF}"/streaming_replication.conf >> "${ROOT_CONF}"/postgresql.conf
  fi
  if [[ -f ${ROOT_CONF}/extra.conf ]];then
    sed -i '/extra.conf/d' "${ROOT_CONF}"/postgresql.conf
    cat "${ROOT_CONF}"/extra.conf >> "${ROOT_CONF}"/postgresql.conf
  fi


}

extension_install() {
  DATABASE=$1
  DB_EXTENSION=$2
  IFS=':'
  read -a strarr <<< "${DB_EXTENSION}"
  EXTENSION_NAME=${strarr[0]}
  EXTENSION_VERSION=${strarr[1]}
  if [[ -z ${EXTENSION_VERSION} ]];then
    if [[ ${EXTENSION_NAME} != 'pg_cron' ]]; then
      echo -e "\e[32m [Entrypoint] Enabling extension \e[1;31m ${EXTENSION_NAME} \e[32m in the database : \e[1;31m ${DATABASE} \033[0m"
      psql "${DATABASE}" -U ${POSTGRES_USER} -p 5432 -h localhost -c "CREATE EXTENSION IF NOT EXISTS \"${EXTENSION_NAME}\" cascade;"
    fi
  else
    if [[ ${EXTENSION_NAME} != 'pg_cron' ]]; then
      pattern="${EXTENSION_NAME}--"
      last_numbers=()
      for file in "$EXTDIR"/"${pattern}"*; do
        filename=$(basename "$file" .sql)
        if [[ "$filename" == *"--"* ]]; then
          last_number=$(echo "$filename" | awk -F '--' '{print $NF}')
          if [[ ! " ${last_numbers[@]} " =~ " $last_number " ]]; then
    	      last_numbers+=("$last_number")
          fi
        fi
      done
      if [[ " ${last_numbers[@]} " =~ " $EXTENSION_VERSION " ]]; then
        echo -e "\e[32m [Entrypoint] Installing extension \e[1;31m ${EXTENSION_NAME}  \e[32m with version \e[1;31m ${EXTENSION_VERSION} \e[32m in the database : \e[1;31m ${DATABASE} \033[0m"
        psql "${DATABASE}" -U ${POSTGRES_USER} -p 5432 -h localhost -c "CREATE EXTENSION IF NOT EXISTS \"${EXTENSION_NAME}\" WITH VERSION '${EXTENSION_VERSION}' cascade;"
      else
        echo -e "\e[32m [Entrypoint] Extension \e[1;31m ${EXTENSION_NAME}  \e[32m with version \e[1;31m ${EXTENSION_VERSION} \e[32m is not available for install, available versions to install are \e[1;31m  "${last_numbers[@]}" \033[0m"
      fi

    fi
  fi

}

non_root_permission() {
  USER="$1"
  GROUP="$2"

  local START_GLOBAL=$(date +%s%N)

  path_envs=(
    "${DATADIR}" "${WAL_ARCHIVE}" "${SCRIPTS_LOCKFILE_DIR}"
    "${CONF_LOCKFILE_DIR}" "${EXTRA_CONF_DIR}" "${SSL_DIR}" "${POSTGRES_INITDB_WALDIR}"
  )

  for dir_name in "${path_envs[@]}"; do
    [[ -n "$dir_name" ]] && directory_checker "$dir_name"
  done

  services=(
    "/usr/lib/postgresql/${POSTGRES_MAJOR_VERSION}/bin"
    "/var/log/postgresql"
    "/var/run/postgresql"
    ${DATADIR}
    "/scripts"
    "/usr/share/postgresql/${POSTGRES_MAJOR_VERSION}"
    "${SSL_DIR}"
    "${WAL_ARCHIVE}"
    "${SCRIPTS_LOCKFILE_DIR}"
    "${CONF_LOCKFILE_DIR}"
    "${EXTRA_CONF_DIR}"
    "/etc/ssl"
    "/etc/postgresql/${POSTGRES_MAJOR_VERSION}/main"
  )

  for path in "${services[@]}"; do
    for expanded in $path; do
      directory_checker "$expanded"
    done
  done
  if [[ -f /tmp/pass_command.txt ]];then
    directory_checker /tmp/pass_command.txt
  fi
  chmod -R 750 "${DATADIR}" ${WAL_ARCHIVE}

  local END_GLOBAL=$(date +%s%N)
  local TOTAL_ELAPSED=$(( (END_GLOBAL - START_GLOBAL) / 1000000 ))
  echo -e "[Entrypoint] Total time spent in non_root_permission, changing ownership of directories: \e[1;31m ${TOTAL_ELAPSED} \e[1;31m ms \033[0m"
}

role_check() {
  ROLE_NAME=$1
  echo "Creating user $1"
  echo -e "\e[32m [Entrypoint] Creating/Updating user \e[1;31m $1  \033[0m"
  RESULT=$(su - postgres -c "psql postgres -t -c \"SELECT 1 FROM pg_roles WHERE rolname = '$ROLE_NAME'\"")
  COMMAND="ALTER"
  if [ -z "$RESULT" ]; then
    export COMMAND="CREATE"
  fi

}

role_creation() {
  ROLE_NAME=$1
  ROLE_STATUS=$2
  ROLE_PASS=$3
  STATEMENT="$COMMAND USER \"$ROLE_NAME\" WITH ${ROLE_STATUS} ENCRYPTED PASSWORD '$ROLE_PASS';"
  echo "$STATEMENT" > /tmp/setup_user.sql
  su - postgres -c "psql postgres -f /tmp/setup_user.sql"
  rm /tmp/setup_user.sql

}

expose_password() {
  local length="$1"
  local label="$2"
  local env_var_name="$3"
  local tmp_file="$4"

  local PASS_FILE="/scripts/.pass_${length}.txt"
  local PASS_VALUE

  # Load from env OR file
  if [[ -n "${!env_var_name}" ]]; then
    PASS_VALUE="${!env_var_name}"
  elif [[ -f "$PASS_FILE" ]]; then
    PASS_VALUE=$(<"$PASS_FILE")
  else
    echo "[Entrypoint] No password found for $label"
    return 1
  fi

  # Export dynamically
  export "$env_var_name"="$PASS_VALUE"

  # Optional: also set PGPASSWORD if it's the main one
  if [[ "$env_var_name" == "POSTGRES_PASS" ]]; then
    export PGPASSWORD="$PASS_VALUE"
  fi

  # Write temp file if provided
  if [[ -n "$tmp_file" ]]; then
    printf "%s" "$PASS_VALUE" > "$tmp_file"
    chmod 600 "$tmp_file"
  fi

  # Display
  echo -e "\e[1;33m[Entrypoint]\033[0m Generated $label password:"
  echo -e "\e[1;34m$PASS_VALUE\033[0m"
}

expose_credentials(){
  expose_password 20 "PostgreSQL" "POSTGRES_PASS" "/tmp/PGPASSWORD.txt"
  expose_password 22 "Replication" "REPLICATION_PASS" "/tmp/REPLPASSWORD.txt"
}

expose_replication(){
  if [[ "${REPLICATION}" =~ [Tt][Rr][Uu][Ee] ]] ; then
    echo "/home/${USER_NAME}/.pgpass" > /tmp/pg_subs.txt
    envsubst < /tmp/pg_subs.txt > /tmp/pass_command.txt
    PGPASSFILE=$(cat /tmp/pass_command.txt)
    rm /tmp/pg_subs.txt /tmp/pass_command.txt
  fi
}

START_COMMAND() {
  local cmd="$*"

  if [[ "${RUN_AS_ROOT,,}" == "false" ]]; then
    exec gosu "$USER_NAME" bash -c "$cmd"
  else
    exec su -s /bin/bash postgres -c "$cmd"
  fi
}


run_service_with_arguments(){
  if [[ "${1:0:1}" = '-' ]]; then
    # append postgres into the arguments
    if [[ ${RUN_AS_ROOT} =~ [Tt][Rr][Uu][Ee] ]];then
      set -- postgres "$@"
    else
      set -- gosu "${USER_NAME}" "$@"
    fi
  fi
}


run_entrypoint_service(){
  if [[ ${RUN_AS_ROOT} =~ [Tt][Rr][Uu][Ee] ]];then
    exec su - "$@"
  else
    exec gosu "${USER_NAME}" - "$@"
  fi
}

