#!/usr/bin/env bash
POSTGRES_MAJOR_VERSION=$(cat /tmp/pg_version.txt)
POSTGIS_MAJOR=$(cat /tmp/pg_major_version.txt)
POSTGIS_MINOR_RELEASE=$(cat /tmp/pg_minor_version.txt)
DEFAULT_DATADIR="/var/lib/postgresql/${POSTGRES_MAJOR_VERSION}/main"
# Commented for documentation. You can specify the location of
# pg_wal directory/volume using the following environment variable:
# POSTGRES_INITDB_WALDIR (default value is unset)
DEFAULT_SCRIPTS_LOCKFILE_DIR="/docker-entrypoint-initdb.d"
DEFAULT_CONF_LOCKFILE_DIR="/settings"
DEFAULT_EXTRA_CONF_DIR="/settings"
ROOT_CONF="/etc/postgresql/${POSTGRES_MAJOR_VERSION}/main"
PG_ENV="$ROOT_CONF/environment"
CONF="$ROOT_CONF/postgresql.conf"
DEFAULT_WAL_ARCHIVE="/opt/archivedir"
RECOVERY_CONF="$ROOT_CONF/recovery.conf"
POSTGRES="/usr/lib/postgresql/${POSTGRES_MAJOR_VERSION}/bin/postgres"
INITDB="/usr/lib/postgresql/${POSTGRES_MAJOR_VERSION}/bin/initdb"
SQLDIR="/usr/share/postgresql/${POSTGRES_MAJOR_VERSION}/contrib/postgis-${POSTGIS_MAJOR}.${POSTGIS_MINOR_RELEASE}/"
EXTDIR="/usr/share/postgresql/${POSTGRES_MAJOR_VERSION}/extension/"
SETVARS="POSTGIS_ENABLE_OUTDB_RASTERS=1 POSTGIS_GDAL_ENABLED_DRIVERS=ENABLE_ALL"
LOCALONLY="-c listen_addresses='127.0.0.1'"
PG_BASEBACKUP="/usr/lib/postgresql/${POSTGRES_MAJOR_VERSION}/bin/pg_basebackup"
NODE_PROMOTION="/usr/lib/postgresql/${POSTGRES_MAJOR_VERSION}/bin/pg_ctl"
DATA_DIR_CONTROL="/usr/lib/postgresql/${POSTGRES_MAJOR_VERSION}/bin/pg_controldata"
PGSTAT_TMP="/var/run/postgresql/"
PG_PID="/var/run/postgresql/${POSTGRES_MAJOR_VERSION}-main.pid"



# Read data from secrets into env variables.

# usage: file_env VAR [DEFAULT]
#    ie: file_env 'XYZ_DB_PASSWORD' 'example'
# (will allow for "$XYZ_DB_PASSWORD_FILE" to fill in the value of
#  "$XYZ_DB_PASSWORD" from a file, especially for Docker's secrets feature)
file_env() {
	local var="$1"
	local fileVar="${var}_FILE"
	local def="${2:-}"
	if [ "${!var:-}" ] && [ "${!fileVar:-}" ]; then
		echo >&2 "error: both $var and $fileVar are set (but are exclusive)"
		exit 1
	fi
	local val="$def"
	if [ "${!var:-}" ]; then
		val="${!var}"
	elif [ "${!fileVar:-}" ]; then
		val="$(< "${!fileVar}")"
	fi
	export "$var"="$val"
	unset "$fileVar"
}

boolean() {
  case $1 in
    [Tt][Rr][Uu][Ee] | [Yy][Ee][Ss])
        echo 'TRUE'
        ;;
    *)
        echo 'FALSE'
        ;;
  esac
}

file_env 'POSTGRES_PASS'
file_env 'POSTGRES_USER'


create_dir() {
DATA_PATH=$1

if [[ ! -d ${DATA_PATH} ]];
then
    echo "Creating" "${DATA_PATH}"  "directory"
    mkdir -p "${DATA_PATH}"
fi
}

generate_random_string() {
  STRING_LENGTH=$1
  random_pass_string=$(cat /dev/urandom | tr -dc '[:alnum:]' | head -c "${STRING_LENGTH}")
  if [[ ! -f /scripts/.pass_${STRING_LENGTH}.txt ]]; then
    echo "${random_pass_string}" > /scripts/.pass_"${STRING_LENGTH}".txt
  fi
  RAND=$(cat /scripts/.pass_"${STRING_LENGTH}".txt)
  export RAND
}

# Make sure we have a user set up
if [ -z "${POSTGRES_USER}" ]; then
	POSTGRES_USER=docker
fi


if [ -z "${POSTGRES_PASS}" ]; then
  generate_random_string 20
	POSTGRES_PASS=${RAND}
fi


if [ -z "${POSTGRES_DBNAME}" ]; then
	POSTGRES_DBNAME=gis
fi
# If datadir is not defined, then use this
if [ -z "${DATADIR}" ]; then
  DATADIR=${DEFAULT_DATADIR}
fi

# RECREATE_DATADIR flag default value
# Always assume that we don't want to recreate datadir if not explicitly defined
# For issue: https://github.com/kartoza/docker-postgis/issues/226
if [ -z "${RECREATE_DATADIR}" ]; then
  RECREATE_DATADIR=FALSE
else
  RECREATE_DATADIR=$(boolean ${RECREATE_DATADIR})
fi
if [ -z "${SSL_DIR}" ]; then
  SSL_DIR="/ssl_certificates"
fi

if [ -z "${WAL_ARCHIVE}" ]; then
   WAL_ARCHIVE=${DEFAULT_WAL_ARCHIVE}
fi

if [ -z "${SCRIPTS_LOCKFILE_DIR}" ]; then
   SCRIPTS_LOCKFILE_DIR=${DEFAULT_SCRIPTS_LOCKFILE_DIR}
fi

if [ -z "${CONF_LOCKFILE_DIR}" ]; then
   CONF_LOCKFILE_DIR=${DEFAULT_CONF_LOCKFILE_DIR}
fi

if [ -z "${EXTRA_CONF_DIR}" ]; then
   EXTRA_CONF_DIR=${DEFAULT_EXTRA_CONF_DIR}
fi

# Enable hstore and topology by default
if [ -z "${HSTORE}" ]; then
	HSTORE=true
fi
if [ -z "${TOPOLOGY}" ]; then
	TOPOLOGY=true
fi
# Replication settings

if [ -z "${REPLICATION}" ]; then
	REPLICATION=false
fi
if [ -z "${REPLICATE_PORT}" ]; then
	REPLICATE_PORT=5432
fi
if [ -z "${DESTROY_DATABASE_ON_RESTART}" ]; then
	DESTROY_DATABASE_ON_RESTART=true
fi
if [ -z "${PG_MAX_WAL_SENDERS}" ]; then
	PG_MAX_WAL_SENDERS=10
fi
if [ -z "${PG_WAL_KEEP_SIZE}" ]; then
	PG_WAL_KEEP_SIZE=20
fi


#Logical replication settings
if [ -z "${MAX_LOGICAL_REPLICATION_WORKERS}" ]; then
  MAX_LOGICAL_REPLICATION_WORKERS=4
fi

if [ -z "${MAX_SYNC_WORKERS_PER_SUBSCRIPTION}" ]; then
  MAX_SYNC_WORKERS_PER_SUBSCRIPTION=2
fi

if [ -z "${IP_LIST}" ]; then
	IP_LIST='*'
fi

if [ -z "${MAINTENANCE_WORKERS}" ]; then
	MAINTENANCE_WORKERS=2
fi

if [ -z "${ARCHIVE_MODE}" ]; then
  # https://www.postgresql.org/docs/12/runtime-config-wal.html
  ARCHIVE_MODE=off
fi

if [ -z "${ARCHIVE_COMPRESSION}" ]; then
  ARCHIVE_COMPRESSION=gzip
fi

if [ -z "${ARCHIVE_DECOMPRESSION}" ]; then
  ARCHIVE_DECOMPRESSION=gunzip
fi

if [ -z "${ARCHIVE_COMMAND}" ]; then
  # https://www.postgresql.org/docs/14/continuous-archiving.html#BACKUP-ARCHIVING-
  if [[ ${ARCHIVE_COMPRESSION} == 'gzip' ]];then
      ARCHIVE_COMMAND="test ! -f ${WAL_ARCHIVE}/%f && gzip  %p > ${WAL_ARCHIVE}/%f.gz "
  else
      ARCHIVE_COMMAND="test ! -f ${WAL_ARCHIVE}/%f && cp %p ${WAL_ARCHIVE}/%f"
  fi
fi

if [ -z "${RESTORE_COMMAND}" ]; then
  # https://www.postgresql.org/docs/14/runtime-config-wal.html
  if [[ "${ARCHIVE_DECOMPRESSION}" == 'gunzip' ]];then
    RESTORE_COMMAND="gunzip < ${WAL_ARCHIVE}/%f.gz > %p"
  else
    RESTORE_COMMAND="cp ${WAL_ARCHIVE}/%f \"%p\""
  fi
fi

if [ -z "${ARCHIVE_CLEANUP_COMMAND}" ]; then
  # https://www.postgresql.org/docs/12/runtime-config-wal.html
  ARCHIVE_CLEANUP_COMMAND="/usr/lib/postgresql/${POSTGRES_MAJOR_VERSION}/bin/pg_archivecleanup ${WAL_ARCHIVE} %r"
fi

if [ -z "${WAL_LEVEL}" ]; then
  # https://www.postgresql.org/docs/12/runtime-config-wal.html
	WAL_LEVEL=replica
fi

if [ -z "${WAL_SIZE}" ]; then
	WAL_SIZE=4GB
fi

if [ -z "${MIN_WAL_SIZE}" ]; then
	MIN_WAL_SIZE=1024MB
fi

if [ -z "${WAL_SEGSIZE}" ]; then
	WAL_SEGSIZE=32
fi

if [ -z "${SHARED_BUFFERS}" ]; then
	SHARED_BUFFERS=256MB
fi

if [ -z "${WORK_MEM}" ]; then
	WORK_MEM=16MB
fi

if [ -z "${WAL_BUFFERS}" ]; then
	WAL_BUFFERS=1MB
fi

if [ -z "${CHECK_POINT_TIMEOUT}" ]; then
	CHECK_POINT_TIMEOUT=30min
fi

if [ -z "${MAX_WORKERS}" ]; then
	MAX_WORKERS=4
fi

if [ -z "${MAINTENANCE_WORK_MEM}" ]; then
	MAINTENANCE_WORK_MEM=128MB
fi


if [ -z "${SSL_CERT_FILE}" ]; then
	SSL_CERT_FILE='/etc/ssl/certs/ssl-cert-snakeoil.pem'
fi

if [ -z "${SSL_KEY_FILE}" ]; then
	SSL_KEY_FILE='/etc/ssl/private/ssl-cert-snakeoil.key'
fi

# controls all login params below, defaults to false
if [ -z "${LOGGING}" ]; then
  LOGGING='FALSE'
fi
# log

if [ -z "${LOGGING_COLLECTOR}" ]; then
  LOGGING_COLLECTOR='off'
fi

if [ -z "${LOG_DIRECTORY}" ]; then
  LOG_DIRECTORY='pg_log'
fi

if [ -z "${LOG_FILENAME}" ]; then
  LOG_FILENAME='postgresql-%Y-%m-%d_%H%M%S.log'
fi

if [ -z "${LOG_ROTATION_AGE}" ]; then
  LOG_ROTATION_AGE='1d'
fi

if [ -z "${LOG_ROTATION_SIZE}" ]; then
  LOG_ROTATION_SIZE='100MB'
fi

if [ -z "${LOG_TRUNCATE_ON_ROTATION}" ]; then
  LOG_TRUNCATE_ON_ROTATION='on'
fi

if [ -z "${LOG_LOCK_WAITS}" ]; then
  LOG_LOCK_WAITS='on'
fi

if [ -z "${LOG_DURATION}" ]; then
  LOG_DURATION='on'
fi

if [ -z "${LOG_STATEMENT}" ]; then
  LOG_STATEMENT='all'
fi

if [ -z "${LOG_MIN_DURATION_STATEMENT}" ]; then
  LOG_MIN_DURATION_STATEMENT='20'
fi

if [ -z "${LOG_CONNECTIONS}" ]; then
  LOG_CONNECTIONS='on'
fi

if [ -z "${LOG_DISCONNECTS}" ]; then
  LOG_DISCONNECTS='on'
fi

if [ -z "${LOG_LINE_PREFIX}" ]; then
  LOG_LINE_PREFIX='%m [%p]: [%l-1] %u@%d '
fi

if [ -z "${LOG_TIMEZONE}" ]; then
  LOG_TIMEZONE='Etc/UTC'
fi


# SSL mode
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




if [ -z "${ALLOW_IP_RANGE}" ]; then
  ALLOW_IP_RANGE='0.0.0.0/0'
fi
if [ -z "${DEFAULT_ENCODING}" ]; then
  DEFAULT_ENCODING="UTF8"
fi

if [ -z "${PGCLIENTENCODING}" ]; then
  PGCLIENTENCODING="UTF8"
fi

get_first_locale() {
    local langs="$1"
    if [ -n "$langs" ]; then
        # Split by comma and get first value
        IFS=',' read -ra lang_arr <<< "$langs"
        # Trim whitespace
        echo "${lang_arr[0]}" | xargs
    else
        echo ""
    fi
}

if [ -z "${LANGS}" ]; then
  LANGS="en_US.UTF-8,id_ID.UTF-8"
fi

# ============================================
# Convert locale from SUPPORTED format to PostgreSQL format
# Example: "uz_UZ@cyrillic UTF-8" -> "uz_UZ.UTF-8@cyrillic"
# Example: "ve_ZA UTF-8" -> "ve_ZA.UTF-8"
# Example: "en_US.UTF-8 UTF-8" -> "en_US.UTF-8"
# ============================================
supported_to_postgres_locale() {
    local locale_line="$1"
    local locale charset

    # Parse locale and charset from line (e.g., "uz_UZ@cyrillic UTF-8")
    locale=$(echo "$locale_line" | awk '{print $1}')
    charset=$(echo "$locale_line" | awk '{print $2}')

    # If charset is empty, try to detect from locale
    if [ -z "$charset" ]; then
        # Check if locale already has charset (e.g., "en_US.UTF-8")
        if [[ "$locale" == *.* ]]; then
            echo "$locale"
            return 0
        else
            # Default to UTF-8
            charset="UTF-8"
        fi
    fi

    # Handle locales with modifier (e.g., "uz_UZ@cyrillic")
    if [[ "$locale" == *@* ]]; then
        local base="${locale%@*}"
        local modifier="${locale#*@}"
        echo "${base}.${charset}@${modifier}"
    else
        # Simple locale without modifier
        echo "${locale}.${charset}"
    fi
}
# ============================================
# Get first locale from LANGS and convert to PostgreSQL format
# ============================================
get_first_postgres_locale() {
    local langs="$1"

    # Get first locale from comma-separated list
    local first_locale=$(echo "${langs%%,*}" | xargs)

    # Convert to PostgreSQL format
    supported_to_postgres_locale "$first_locale"
}


if [ -z "${DEFAULT_COLLATION}" ]; then
    FIRST_LOCALE=$(get_first_postgres_locale "$LANGS")
    if [ -n "$FIRST_LOCALE" ]; then
        DEFAULT_COLLATION="$FIRST_LOCALE"
    else
        DEFAULT_COLLATION="en_US.UTF-8"
    fi
fi
if [ -z "${DEFAULT_CTYPE}" ]; then
    FIRST_LOCALE=$(get_first_postgres_locale "$LANGS")
    if [ -n "$FIRST_LOCALE" ]; then
        DEFAULT_CTYPE="$FIRST_LOCALE"
    else
        DEFAULT_CTYPE="en_US.UTF-8"
    fi
fi

if [ -z "${TARGET_TIMELINE}" ]; then
	TARGET_TIMELINE='latest'
fi

if [ -z "${TARGET_ACTION}" ]; then
	TARGET_ACTION='promote'
fi

if [ -z "${REPLICATION_USER}" ]; then
  REPLICATION_USER=replicator
fi

if [ -z "${REPLICATION_PASS}" ]; then
  generate_random_string 22
	REPLICATION_PASS=${RAND}
fi

if [ -z "$IGNORE_INIT_HOOK_LOCKFILE" ]; then
    IGNORE_INIT_HOOK_LOCKFILE=false
fi

if [ -z "$EXTRA_CONF" ]; then
    EXTRA_CONF=""
fi

if [ -z "$ACTIVATE_CRON" ]; then
    ACTIVATE_CRON=TRUE
fi

if [ -z "${SHARED_PRELOAD_LIBRARIES}" ]; then
  libs=()

  # add timescaledb if installed
  if dpkg -l | grep -q "timescaledb"; then
    libs+=("timescaledb")
  fi

  # add pg_cron if activated
  if [[ ${ACTIVATE_CRON} =~ [Tt][Rr][Uu][Ee] ]]; then
    libs+=("pg_cron")
  fi

  # add pg_duckdb if extension is built/installed
  if [ -f "$(pg_config --pkglibdir)/pg_duckdb.so" ]; then
    libs+=("pg_duckdb")
  fi

  # join with commas
  if [ ${#libs[@]} -gt 0 ]; then
    SHARED_PRELOAD_LIBRARIES=$(IFS=,; echo "${libs[*]}")
  fi
fi

if [ -z "${POSTGRES_MULTIPLE_EXTENSIONS}" ]; then
    DEFAULT_EXTENSIONS="postgis,hstore,postgis_topology,postgis_raster,pgrouting"

    # start with defaults
    POSTGRES_MULTIPLE_EXTENSIONS="${DEFAULT_EXTENSIONS}"

    # append any preload libraries that are also extensions
    if [ -n "${SHARED_PRELOAD_LIBRARIES}" ]; then
        POSTGRES_MULTIPLE_EXTENSIONS="${POSTGRES_MULTIPLE_EXTENSIONS},${SHARED_PRELOAD_LIBRARIES}"
    fi

    export POSTGRES_MULTIPLE_EXTENSIONS
fi


if [ -z "$PASSWORD_AUTHENTICATION" ]; then
    PASSWORD_AUTHENTICATION="scram-sha-256"
fi

if [ -z "${ALL_DATABASES}" ]; then
  ALL_DATABASES=FALSE
fi

if [ -z "${FORCE_SSL}" ]; then
  FORCE_SSL=FALSE
fi

if [ -z "${ACCEPT_TIMESCALE_TUNING}" ]; then
  ACCEPT_TIMESCALE_TUNING=FALSE
fi

if [ -z "${TIMESCALE_TUNING_PARAMS}" ]; then
  TIMESCALE_TUNING_PARAMS=
fi

if [ -z "${TIMESCALE_TUNING_CONFIG}" ]; then
  TIMESCALE_TUNING_CONFIG=time_scale_tuning.conf
fi

if [ -z "${RUN_AS_ROOT}" ]; then
  RUN_AS_ROOT=true
fi




# Compatibility with official postgres variable
# Official postgres variable gets priority
if [ -n "${POSTGRES_PASSWORD}" ]; then
	POSTGRES_PASS=${POSTGRES_PASSWORD}
fi
if [ -n "${PGDATA}" ]; then
	DATADIR=${PGDATA}
fi

if [ -n "${POSTGRES_DB}" ]; then
	POSTGRES_DBNAME=${POSTGRES_DB}
fi

if [ -n "${POSTGRES_INITDB_ARGS}" ]; then
  INITDB_EXTRA_ARGS=${POSTGRES_INITDB_ARGS}
fi

IFS=','
read -a dbarr <<< "$POSTGRES_DBNAME"
export SINGLE_DB=${dbarr[0]}



if [ -z "${TIMEZONE}" ]; then
  TIMEZONE='Etc/UTC'
fi

if [ -z "${KERNEL_SHMMAX}" ]; then
  KERNEL_SHMMAX=543252480
fi

if [ -z "${KERNEL_SHMALL}" ]; then
  KERNEL_SHMALL=2097152
fi

if [ -z "${PROMOTE_MASTER}" ]; then
  PROMOTE_MASTER=FALSE
fi
# usable definitions
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



# Running extended script or sql if provided.
# Useful for people who extends the image.

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
  local conf_files=(
    "postgis.conf"
    "logical_replication.conf"
    "streaming_replication.conf"
    "extra.conf"
  )

  for file in "${conf_files[@]}"; do
    local path="${ROOT_CONF}/${file}"
    if [[ -f "$path" ]]; then
      sed -i "/${file}/d" "${ROOT_CONF}/postgresql.conf"
      cat "$path" >> "${ROOT_CONF}/postgresql.conf"
    fi
  done
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

directory_checker() {
  local DATA_PATH=$1
  if [ -d "$DATA_PATH" ]; then
    local DB_USER_PERM
    local DB_GRP_PERM
    DB_USER_PERM=$(stat -c '%U' "${DATA_PATH}")
    DB_GRP_PERM=$(stat -c '%G' "${DATA_PATH}")

    if [[ ${DB_USER_PERM} != "${USER}" ]] || [[ ${DB_GRP_PERM} != "${GROUP}" ]]; then
      chown -R "${USER}:${GROUP}" "${DATA_PATH}"
    fi
  else
    chown "${USER}:${GROUP}" "${DATA_PATH}"
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
    "/usr/lib/postgresql/${POSTGRES_MAJOR_VERSION}/bin"  "/var/log/postgresql"  
    "/var/run/postgresql" ${DATADIR} "/scripts" "/usr/share/postgresql/${POSTGRES_MAJOR_VERSION}"
    "${SSL_DIR}" "${WAL_ARCHIVE}" "${SCRIPTS_LOCKFILE_DIR}" "${CONF_LOCKFILE_DIR}" "${EXTRA_CONF_DIR}" "/etc/ssl"
    "/etc/postgresql/${POSTGRES_MAJOR_VERSION}/main" "/tmp/pg_*"
  )

  for path in "${services[@]}"; do
    for expanded in $path; do
      directory_checker "$expanded"
    done
  done
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


# ============================================
# Helper function: Check if locale is supported
# ============================================
is_locale_supported() {
    local locale="$1"

    # Check in /etc/all.locale.gen (custom master list)
    if grep -qi "^${locale}" /etc/all.locale.gen 2>/dev/null; then
        return 0
    fi

    # Check in /usr/share/i18n/SUPPORTED (Debian canonical list)
    if [ -f "/usr/share/i18n/SUPPORTED" ] && grep -qi "^${locale}" /usr/share/i18n/SUPPORTED 2>/dev/null; then
        return 0
    fi

    return 1
}
# ============================================
# Helper function: Get locale line from source files
# ============================================

get_locale_line() {
    local locale="$1"

    # Try custom master list first
    if grep -i "^${locale}" /etc/all.locale.gen 2>/dev/null; then
        return 0
    fi

    # Try Debian canonical list as fallback
    if [ -f "/usr/share/i18n/SUPPORTED" ] && grep -i "^${locale}" /usr/share/i18n/SUPPORTED 2>/dev/null; then
        return 0
    fi

    return 1
}

# ============================================
# Function: Generate a single locale
# ============================================
generate_single_locale() {
    local locale_line="$1"
    local locale_file="/etc/locale.gen"

    # Parse locale name (first field)
    local locale_name=$(echo "$locale_line" | awk '{print $1}')

    # Skip if locale is C or C.UTF-8 (always available)
    if [[ "$locale_name" == "C" ]] || [[ "$locale_name" == "C.UTF-8" ]]; then
        echo -e "\e[32m [Entrypoint] Using built-in locale: \e[1;33m$locale_name\033[0m"
        return 0
    fi

    # Skip empty
    if [ -z "$locale_name" ]; then
        return 0
    fi

    # Convert to PostgreSQL format for checking
    local postgres_locale=$(supported_to_postgres_locale "$locale_line")

    # Check if locale already exists in system
    if locale -a 2>/dev/null | grep -qi "^${postgres_locale}$"; then
        echo -e "\e[32m [Entrypoint] Locale already available: \e[1;33m$postgres_locale\033[0m"
        return 0
    fi

    # Check if locale is supported
    if ! is_locale_supported "$locale_name"; then
        echo -e "\e[33m [Entrypoint] Warning: \e[1;33m$locale_name\e[0m\e[33m not found in locale lists\033[0m"
        return 1
    fi

    # Add to locale.gen (use original format)
    if [ ! -f "$locale_file" ] || [ ! -s "$locale_file" ]; then
        echo "$locale_line" > "$locale_file"
    else
        # Check if already in file to avoid duplicates
        if ! grep -qi "^${locale_name}" "$locale_file"; then
            echo "$locale_line" >> "$locale_file"
        fi
    fi

    # Generate the locale
    if /usr/sbin/locale-gen 2>/dev/null; then
        echo -e "\e[32m [Entrypoint] Successfully generated: \e[1;33m$postgres_locale\033[0m"
        return 0
    else
        echo -e "\e[31m [Entrypoint] Failed to generate: \e[1;33m$postgres_locale\033[0m"
        return 1
    fi
}

# ============================================
# Function: Generate multiple locales from LANGS
# ============================================
generate_multiple_locales() {
    local langs="$1"
    local locale_file="/etc/locale.gen"

    echo -e "\e[36m [Entrypoint] Processing locales from: \e[1;33m$langs\033[0m"

    # Clear locale.gen
    > "$locale_file"

    IFS=',' read -ra LANG_ARR <<< "$langs"
    local generated_count=0
    local valid_locales=()
    local postgres_locales=()

    for locale_line in "${LANG_ARR[@]}"; do
        locale_line=$(echo "$locale_line" | xargs)  # Trim whitespace

        # Skip empty strings
        if [ -z "$locale_line" ]; then
            continue
        fi

        # Get locale name (first field)
        local locale_name=$(echo "$locale_line" | awk '{print $1}')

        # Skip built-in locales
        if [[ "$locale_name" == "C" ]] || [[ "$locale_name" == "C.UTF-8" ]]; then
            echo -e "\e[36m [Entrypoint] Skipping built-in locale: \e[1;33m$locale_name\033[0m"
            continue
        fi

        # Get the locale line from source files
        if get_locale_line "$locale_name" >> "$locale_file"; then
            local postgres_locale=$(supported_to_postgres_locale "$locale_line")
            echo -e "\e[32m [Entrypoint] Added: \e[1;33m$postgres_locale\033[0m"
            valid_locales+=("$locale_line")
            postgres_locales+=("$postgres_locale")
            ((generated_count++))
        else
            echo -e "\e[33m [Entrypoint] Skipped: \e[1;33m$locale_name\e[0m\e[33m (not found in locale lists)\033[0m"
        fi
    done

    # Generate if we have any locales
    if [ ${#valid_locales[@]} -gt 0 ]; then
        echo -e "\e[36m [Entrypoint] Running locale-gen for \e[1;33m$generated_count\e[0m\e[36m locale(s)...\033[0m"
        if /usr/sbin/locale-gen 2>/dev/null; then
            echo -e "\e[32m [Entrypoint] Successfully generated: \e[1;33m${postgres_locales[*]}\033[0m"
            return 0
        else
            echo -e "\e[31m [Entrypoint] locale-gen failed\033[0m"
            return 1
        fi
    else
        echo -e "\e[33m [Entrypoint] No valid locales to generate\033[0m"
        return 1
    fi
}

# ============================================
# Helper function: Get original locale format from PostgreSQL format
# ============================================
get_original_locale_format() {
    local postgres_locale="$1"

    # Extract components
    local base_without_charset=$(echo "$postgres_locale" | cut -d'.' -f1)
    local charset=$(echo "$postgres_locale" | cut -d'.' -f2 | cut -d'@' -f1)
    local modifier=""

    if [[ "$postgres_locale" == *@* ]]; then
        modifier="@${postgres_locale#*@}"
    fi

    # Construct the original format (without charset in the locale name)
    if [ -n "$modifier" ]; then
        # Remove the @modifier from base for checking
        local base_no_modifier=$(echo "$base_without_charset" | cut -d'@' -f1)
        echo "${base_no_modifier}${modifier} ${charset}"
    else
        echo "${base_without_charset} ${charset}"
    fi
}



locale_install() {
    SETUP_LOCKFILE="${EXTRA_CONF_DIR:-/var/lib/postgresql}/.locales.lock"
    LOCALE_CONFIG_HASH_FILE="${EXTRA_CONF_DIR:-/var/lib/postgresql}/.locales_config_hash"

    # Set default LANGS if not provided
    if [ -z "${LANGS}" ]; then
        LANGS="en_US.UTF-8 UTF-8,id_ID.UTF-8 UTF-8"
        echo -e "\e[36m [Entrypoint] Using default LANGS: \e[1;33m${LANGS}\033[0m"
    fi

    # Calculate current configuration hash
    CURRENT_CONFIG_HASH=$(echo "${LANGS}:${DEFAULT_COLLATION}:${DEFAULT_CTYPE}" | md5sum | cut -d' ' -f1)

    # Check if locales need to be regenerated
    NEEDS_REGENERATION=0

    if [ ! -f "$SETUP_LOCKFILE" ]; then
        echo -e "\e[36m [Entrypoint] First run detected - preparing PostgreSQL locales...\033[0m"
        NEEDS_REGENERATION=1
    elif [ -f "$LOCALE_CONFIG_HASH_FILE" ]; then
        STORED_CONFIG_HASH=$(cat "$LOCALE_CONFIG_HASH_FILE")
        if [ "$CURRENT_CONFIG_HASH" != "$STORED_CONFIG_HASH" ]; then
            echo -e "\e[33m [Entrypoint] Locale configuration changed - regenerating locales...\033[0m"
            NEEDS_REGENERATION=1
            rm -f "$SETUP_LOCKFILE"
        else
            echo -e "\e[32m [Entrypoint] Locales already configured with current settings, skipping generation\033[0m"
            return 0
        fi
    else
        echo -e "\e[33m [Entrypoint] Inconsistent locale state, regenerating...\033[0m"
        NEEDS_REGENERATION=1
        rm -f "$SETUP_LOCKFILE"
    fi

    if [ $NEEDS_REGENERATION -eq 0 ]; then
        return 0
    fi

    # Create lockfile directory
    mkdir -p "$(dirname "$SETUP_LOCKFILE")"

    # Generate locales from LANGS
    if ! generate_multiple_locales "${LANGS}"; then
        echo -e "\e[33m [Entrypoint] Failed to generate some locales, using fallback\033[0m"
        if ! locale -a 2>/dev/null | grep -qi "en_US.UTF-8"; then
            generate_single_locale "en_US.UTF-8 UTF-8"
        fi
    fi

    # Check if DEFAULT_COLLATION is already covered by LANGS (in PostgreSQL format)
    local collation_covered=0
    local ctype_covered=0

    # Extract locale names from LANGS (original format)
    IFS=',' read -ra LANG_ARR <<< "$LANGS"
    for locale_line in "${LANG_ARR[@]}"; do
        locale_line=$(echo "$locale_line" | xargs)
        local postgres_format=$(supported_to_postgres_locale "$locale_line")

        # Check if DEFAULT_COLLATION matches any generated locale
        if [ -n "${DEFAULT_COLLATION}" ] && [ "$postgres_format" = "${DEFAULT_COLLATION}" ]; then
            collation_covered=1
        fi

        # Check if DEFAULT_CTYPE matches any generated locale
        if [ -n "${DEFAULT_CTYPE}" ] && [ "$postgres_format" = "${DEFAULT_CTYPE}" ]; then
            ctype_covered=1
        fi
    done

    # Also check if DEFAULT_COLLATION/DEFAULT_CTYPE are the same as first locale
    local first_postgres_locale=$(get_first_postgres_locale "$LANGS")
    if [ -n "${DEFAULT_COLLATION}" ] && [ "$first_postgres_locale" = "${DEFAULT_COLLATION}" ]; then
        collation_covered=1
    fi

    if [ -n "${DEFAULT_CTYPE}" ] && [ "$first_postgres_locale" = "${DEFAULT_CTYPE}" ]; then
        ctype_covered=1
    fi

    # Only generate DEFAULT_COLLATION if not already covered
    if [ -n "${DEFAULT_COLLATION}" ] && [ $collation_covered -eq 0 ]; then
        # Need to find the original format for this locale
        local original_format=$(get_original_locale_format "${DEFAULT_COLLATION}")
        if [ -n "$original_format" ]; then
            echo -e "\e[36m [Entrypoint] Generating additional locale from DEFAULT_COLLATION: \e[1;33m${DEFAULT_COLLATION}\033[0m"
            generate_single_locale "$original_format"
        else
            echo -e "\e[33m [Entrypoint] Skipping DEFAULT_COLLATION: \e[1;33m${DEFAULT_COLLATION}\e[0m\e[33m (already covered or not found)\033[0m"
        fi
    fi

    # Only generate DEFAULT_CTYPE if different from COLLATION and not already covered
    if [ -n "${DEFAULT_CTYPE}" ] && [ "${DEFAULT_CTYPE}" != "${DEFAULT_COLLATION}" ] && [ $ctype_covered -eq 0 ]; then
        local original_format=$(get_original_locale_format "${DEFAULT_CTYPE}")
        if [ -n "$original_format" ]; then
            echo -e "\e[36m [Entrypoint] Generating additional locale from DEFAULT_CTYPE: \e[1;33m${DEFAULT_CTYPE}\033[0m"
            generate_single_locale "$original_format"
        else
            echo -e "\e[33m [Entrypoint] Skipping DEFAULT_CTYPE: \e[1;33m${DEFAULT_CTYPE}\e[0m\e[33m (already covered or not found)\033[0m"
        fi
    fi

    # Save configuration hash and create lockfile
    echo "$CURRENT_CONFIG_HASH" > "$LOCALE_CONFIG_HASH_FILE"
    touch "$SETUP_LOCKFILE"
    echo -e "\e[32m [Entrypoint] Locale setup complete (config hash: \e[1;33m${CURRENT_CONFIG_HASH:0:8}...\e[0m\e[32m)\033[0m"
}

