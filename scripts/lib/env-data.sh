#!/usr/bin/env bash

#############################################
# Functions
#############################################
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

generate_random_string() {
  local length="$1"
  local file="/scripts/.pass_${length}.txt"

  [[ -f "${file}" ]] || tr -dc '[:alnum:]' </dev/urandom | head -c "${length}" > "${file}"
  RAND="$(<"${file}")"
  export RAND
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

env_default() {
  local var="$1"
  local default="$2"

  if [[ -z "${!var:-}" ]]; then
    export "${var}=${default}"
  fi
}

#############################################
# Env variables
#############################################

env_default POSTGRES_MAJOR_VERSION "$(cat /tmp/pg_version.txt)"
env_default POSTGIS_MAJOR "$(cat /tmp/pg_major_version.txt)"
env_default POSTGIS_MINOR_RELEASE "$(cat /tmp/pg_minor_version.txt)"
env_default DEFAULT_DATADIR "/var/lib/postgresql/${POSTGRES_MAJOR_VERSION}/main"
env_default DEFAULT_SCRIPTS_LOCKFILE_DIR "/docker-entrypoint-initdb.d"
env_default DEFAULT_CONF_LOCKFILE_DIR "/settings"
env_default DEFAULT_EXTRA_CONF_DIR "/settings"
env_default ROOT_CONF "/etc/postgresql/${POSTGRES_MAJOR_VERSION}/main"
env_default PG_ENV "$ROOT_CONF/environment"
env_default CONF "$ROOT_CONF/postgresql.conf"
env_default DEFAULT_WAL_ARCHIVE "/opt/archivedir"
env_default RECOVERY_CONF "$ROOT_CONF/recovery.conf"
env_default POSTGRES "/usr/lib/postgresql/${POSTGRES_MAJOR_VERSION}/bin/postgres"
env_default INITDB "/usr/lib/postgresql/${POSTGRES_MAJOR_VERSION}/bin/initdb"
env_default SQLDIR "/usr/share/postgresql/${POSTGRES_MAJOR_VERSION}/contrib/postgis-${POSTGIS_MAJOR}.${POSTGIS_MINOR_RELEASE}/"
env_default EXTDIR "/usr/share/postgresql/${POSTGRES_MAJOR_VERSION}/extension/"
env_default SETVARS "POSTGIS_ENABLE_OUTDB_RASTERS=1 POSTGIS_GDAL_ENABLED_DRIVERS=ENABLE_ALL"
env_default LOCALONLY "-c listen_addresses='127.0.0.1'"
env_default PG_BASEBACKUP "/usr/lib/postgresql/${POSTGRES_MAJOR_VERSION}/bin/pg_basebackup"
env_default NODE_PROMOTION "/usr/lib/postgresql/${POSTGRES_MAJOR_VERSION}/bin/pg_ctl"
env_default DATA_DIR_CONTROL "/usr/lib/postgresql/${POSTGRES_MAJOR_VERSION}/bin/pg_controldata"
env_default PGSTAT_TMP "/var/run/postgresql/"
env_default PG_PID "/var/run/postgresql/${POSTGRES_MAJOR_VERSION}-main.pid"

########################################
# Core defaults
########################################
file_env 'POSTGRES_PASS'
file_env 'POSTGRES_USER'


env_default POSTGRES_USER "docker"
env_default POSTGRES_DBNAME "gis"
env_default DATADIR "${DEFAULT_DATADIR}"
env_default SSL_DIR "/ssl_certificates"
env_default WAL_ARCHIVE "${DEFAULT_WAL_ARCHIVE}"
env_default SCRIPTS_LOCKFILE_DIR "${DEFAULT_SCRIPTS_LOCKFILE_DIR}"
env_default CONF_LOCKFILE_DIR "${DEFAULT_CONF_LOCKFILE_DIR}"
env_default EXTRA_CONF_DIR "${DEFAULT_EXTRA_CONF_DIR}"

if [ -z "${POSTGRES_PASS}" ]; then
  generate_random_string 20
	POSTGRES_PASS=${RAND}
fi

# RECREATE_DATADIR flag default value
# Always assume that we don't want to recreate datadir if not explicitly defined
# For issue: https://github.com/kartoza/docker-postgis/issues/226
if [ -z "${RECREATE_DATADIR}" ]; then
  RECREATE_DATADIR=FALSE
else
  RECREATE_DATADIR=$(boolean ${RECREATE_DATADIR})
fi
# Enable hstore and topology by default
env_default HSTORE "true"
env_default TOPOLOGY "true"
# Replication settings
env_default REPLICATION "false"
env_default REPLICATE_PORT "5432"
env_default DESTROY_DATABASE_ON_RESTART "true"
env_default PG_MAX_WAL_SENDERS "10"
env_default PG_WAL_KEEP_SIZE "20"

#Logical replication settings
env_default MAX_LOGICAL_REPLICATION_WORKERS "4"
env_default MAX_SYNC_WORKERS_PER_SUBSCRIPTION "2"
env_default IP_LIST "*"
env_default MAINTENANCE_WORKERS "2"
env_default ARCHIVE_MODE "off"
env_default ARCHIVE_COMPRESSION "gzip"
env_default ARCHIVE_DECOMPRESSION "gunzip"



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

env_default ARCHIVE_CLEANUP_COMMAND "/usr/lib/postgresql/${POSTGRES_MAJOR_VERSION}/bin/pg_archivecleanup ${WAL_ARCHIVE} %r"
env_default WAL_LEVEL "replica"
env_default WAL_SIZE "4GB"
env_default MIN_WAL_SIZE "1024MB"
env_default WAL_SEGSIZE "32"
env_default SHARED_BUFFERS "256MB"
env_default WORK_MEM "16MB"
env_default WAL_BUFFERS "1MB"
env_default CHECK_POINT_TIMEOUT "30min"
env_default MAX_WORKERS "4"
env_default MAINTENANCE_WORK_MEM "128MB"
env_default SSL_CERT_FILE "/etc/ssl/certs/ssl-cert-snakeoil.pem"
env_default SSL_KEY_FILE "/etc/ssl/private/ssl-cert-snakeoil.key"

# controls all login params below, defaults to false
env_default LOGGING "FALSE"
env_default LOGGING_COLLECTOR "off"
env_default LOG_DIRECTORY "pg_log"
env_default LOG_FILENAME "postgresql-%Y-%m-%d_%H%M%S.log"
env_default LOG_ROTATION_AGE "1d"
env_default LOG_ROTATION_SIZE "100MB"
env_default LOG_TRUNCATE_ON_ROTATION "on"
env_default LOG_LOCK_WAITS "on"
env_default LOG_DURATION "on"
env_default LOG_STATEMENT "all"
env_default LOG_MIN_DURATION_STATEMENT "20"
env_default LOG_CONNECTIONS "on"
env_default LOG_DISCONNECTS "on"
env_default LOG_LINE_PREFIX "%m [%p]: [%l-1] %u@%d "
env_default LOG_TIMEZONE "Etc/UTC"
# SSL mode

if [ -z "${POSTGRES_MULTIPLE_EXTENSIONS}" ]; then
    DEFAULT_EXTENSIONS="postgis,hstore,postgis_topology,postgis_raster,pgrouting"
    if [[ $(dpkg -l | grep "timescaledb") > /dev/null ]];then
        POSTGRES_MULTIPLE_EXTENSIONS="${DEFAULT_EXTENSIONS},timescaledb"
    else
        POSTGRES_MULTIPLE_EXTENSIONS="${DEFAULT_EXTENSIONS}"
    fi
fi

env_default ALLOW_IP_RANGE "0.0.0.0/0"
env_default DEFAULT_ENCODING "UTF8"
env_default PGCLIENTENCODING "UTF8"
env_default DEFAULT_COLLATION "en_US.UTF-8"
env_default DEFAULT_CTYPE "en_US.UTF-8"
env_default TARGET_TIMELINE "latest"
env_default TARGET_ACTION "promote"
env_default REPLICATION_USER "replicator"

if [ -z "${REPLICATION_PASS}" ]; then
  generate_random_string 22
	REPLICATION_PASS=${RAND}
fi

env_default IGNORE_INIT_HOOK_LOCKFILE "false"
env_default EXTRA_CONF ""
env_default ACTIVATE_CRON "TRUE"

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



env_default PASSWORD_AUTHENTICATION "scram-sha-256"
env_default ALL_DATABASES "FALSE"
env_default FORCE_SSL "FALSE"
env_default ACCEPT_TIMESCALE_TUNING "FALSE"
env_default TIMESCALE_TUNING_PARAMS ""
env_default TIMESCALE_TUNING_CONFIG "time_scale_tuning.conf"
env_default RUN_AS_ROOT "true"
env_default TIMEZONE "Etc/UTC"
env_default KERNEL_SHMMAX "543252480"
env_default KERNEL_SHMALL "2097152"
env_default PROMOTE_MASTER "FALSE"


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



