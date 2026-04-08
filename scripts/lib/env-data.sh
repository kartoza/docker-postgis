#!/usr/bin/env bash



#############################################
# Env variables
#############################################

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


file_env 'POSTGRES_PASS'
file_env 'POSTGRES_USER'

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

if [ -z "${POSTGRES_MULTIPLE_EXTENSIONS}" ]; then
    if [[ $(dpkg -l | grep "timescaledb") > /dev/null ]];then
        POSTGRES_MULTIPLE_EXTENSIONS='postgis,hstore,postgis_topology,postgis_raster,pgrouting,timescaledb'
    else
        POSTGRES_MULTIPLE_EXTENSIONS='postgis,hstore,postgis_topology,postgis_raster,pgrouting'
    fi
fi


if [ -z "${ALLOW_IP_RANGE}" ]; then
  ALLOW_IP_RANGE='0.0.0.0/0'
fi

if [ -z "${DEFAULT_ENCODING}" ]; then
  DEFAULT_ENCODING="UTF8"
fi

if [ -z "${PGCLIENTENCODING}" ]; then
  PGCLIENTENCODING="UTF8"
fi

if [ -z "${DEFAULT_COLLATION}" ]; then
  DEFAULT_COLLATION="en_US.UTF-8"
fi
if [ -z "${DEFAULT_CTYPE}" ]; then
  DEFAULT_CTYPE="en_US.UTF-8"
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
    if [[ $(dpkg -l | grep "timescaledb") > /dev/null ]];then
        if [[ ${ACTIVATE_CRON} =~ [Tt][Rr][Uu][Ee] ]];then
          SHARED_PRELOAD_LIBRARIES='pg_cron,timescaledb'
        else
          SHARED_PRELOAD_LIBRARIES='timescaledb'
        fi
    else
        if [[ ${ACTIVATE_CRON} =~ [Tt][Rr][Uu][Ee] ]];then
          SHARED_PRELOAD_LIBRARIES='pg_cron'
        fi
    fi
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

