#!/usr/bin/env bash

DATADIR="/var/lib/postgresql/12/main"
ROOT_CONF="/etc/postgresql/12/main"
PG_ENV="$ROOT_CONF/environment"
CONF="$ROOT_CONF/postgresql.conf"
WAL_ARCHIVE="/opt/archivedir"
RECOVERY_CONF="$ROOT_CONF/recovery.conf"
POSTGRES="/usr/lib/postgresql/12/bin/postgres"
INITDB="/usr/lib/postgresql/12/bin/initdb"
SQLDIR="/usr/share/postgresql/12/contrib/postgis-3.0/"
SETVARS="POSTGIS_ENABLE_OUTDB_RASTERS=1 POSTGIS_GDAL_ENABLED_DRIVERS=ENABLE_ALL"
LOCALONLY="-c listen_addresses='127.0.0.1'"
PG_BASEBACKUP="/usr/bin/pg_basebackup"
PROMOTE_FILE="/tmp/pg_promote_master"
PGSTAT_TMP="/var/run/postgresql/"
PG_PID="/var/run/postgresql/12-main.pid"


# Read data from secrets into env variables.

# usage: file_env VAR [DEFAULT]
#    ie: file_env 'XYZ_DB_PASSWORD' 'example'
# (will allow for "$XYZ_DB_PASSWORD_FILE" to fill in the value of
#  "$XYZ_DB_PASSWORD" from a file, especially for Docker's secrets feature)
function file_env {
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

file_env 'POSTGRES_PASS'
file_env 'POSTGRES_USER'
file_env 'POSTGRES_DBNAME'

# Make sure we have a user set up
if [ -z "${POSTGRES_USER}" ]; then
	POSTGRES_USER=docker
fi
if [ -z "${POSTGRES_PASS}" ]; then
	POSTGRES_PASS=docker
fi
if [ -z "${POSTGRES_DBNAME}" ]; then
	POSTGRES_DBNAME=gis
fi
# SSL mode
if [ -z "${PGSSLMODE}" ]; then
	PGSSLMODE=require
fi
# Enable hstore and topology by default
if [ -z "${HSTORE}" ]; then
	HSTORE=true
fi
if [ -z "${TOPOLOGY}" ]; then
	TOPOLOGY=true
fi
# Replication settings
if [ -z "${REPLICATE_PORT}" ]; then
	REPLICATE_PORT=5432
fi
if [ -z "${DESTROY_DATABASE_ON_RESTART}" ]; then
	DESTROY_DATABASE_ON_RESTART=true
fi
if [ -z "${PG_MAX_WAL_SENDERS}" ]; then
	PG_MAX_WAL_SENDERS=10
fi
if [ -z "${PG_WAL_KEEP_SEGMENTS}" ]; then
	PG_WAL_KEEP_SEGMENTS=250
fi

if [ -z "${IP_LIST}" ]; then
	IP_LIST='*'
fi

if [ -z "${MAINTAINANCE_WORKERS}" ]; then
	MAINTAINANCE_WORKERS=2
fi

if [ -z "${ARCHIVE_MODE}" ]; then
  # https://www.postgresql.org/docs/12/runtime-config-wal.html
  ARCHIVE_MODE=off
fi

if [ -z "${ARCHIVE_COMMAND}" ]; then
  # https://www.postgresql.org/docs/12/continuous-archiving.html#BACKUP-ARCHIVING-WAL
  ARCHIVE_COMMAND="test ! -f ${WAL_ARCHIVE}/%f && cp %p ${WAL_ARCHIVE}/%f"
fi

if [ -z "${RESTORE_COMMAND}" ]; then
  # https://www.postgresql.org/docs/12/runtime-config-wal.html
  RESTORE_COMMAND="cp ${WAL_ARCHIVE}/%f \"%p\""
fi

if [ -z "${ARCHIVE_CLEANUP_COMMAND}" ]; then
  # https://www.postgresql.org/docs/12/runtime-config-wal.html
  ARCHIVE_CLEANUP_COMMAND="pg_archivecleanup ${WAL_ARCHIVE} %r"
fi

if [ -z "${WAL_LEVEL}" ]; then
  # https://www.postgresql.org/docs/12/runtime-config-wal.html
	WAL_LEVEL=replica
fi

if [ -z "${WAL_SIZE}" ]; then
	WAL_SIZE=4GB
fi

if [ -z "${MIN_WAL_SIZE}" ]; then
	MIN_WAL_SIZE=2048MB
fi

if [ -z "${WAL_SEGSIZE}" ]; then
	WAL_SEGSIZE=1024
fi

if [ -z "${CHECK_POINT_TIMEOUT}" ]; then
	CHECK_POINT_TIMEOUT=30min
fi

if [ -z "${MAX_WORKERS}" ]; then
	MAX_WORKERS=4
fi

if [ -z "${MAINTAINANCE_WORK_MEM}" ]; then
	MAINTAINANCE_WORK_MEM=128MB
fi


if [ -z "${SSL_CERT_FILE}" ]; then
	SSL_CERT_FILE='/etc/ssl/certs/ssl-cert-snakeoil.pem'
fi

if [ -z "${SSL_KEY_FILE}" ]; then
	SSL_KEY_FILE='/etc/ssl/private/ssl-cert-snakeoil.key'
fi

if [ -z "${POSTGRES_MULTIPLE_EXTENSIONS}" ]; then
  POSTGRES_MULTIPLE_EXTENSIONS='postgis,hstore,postgis_topology,postgis_raster'
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
  REPLICATION_PASS=replicator
fi


if [ -z "$EXTRA_CONF" ]; then
    EXTRA_CONF=""
fi

# Compatibility with official postgres variable
# Official postgres variable gets priority
if [ ! -z "${POSTGRES_PASSWORD}" ]; then
	POSTGRES_PASS=${POSTGRES_PASSWORD}
fi
if [ ! -z "${PGDATA}" ]; then
	DATADIR=${PGDATA}
fi

if [ ! -z "$POSTGRES_DB" ]; then
	POSTGRES_DBNAME=${POSTGRES_DB}
fi

list=(`echo ${POSTGRES_DBNAME} | tr ',' ' '`)
arr=(${list})
SINGLE_DB=${arr[0]}
# usable function definitions
function restart_postgres {
PID=`cat ${PG_PID}`
kill -TERM ${PID}

# Wait for background postgres main process to exit
while [[ "$(ls -A ${PG_PID} 2>/dev/null)" ]]; do
  sleep 1
done

# Brought postgres back up again
source /env-data.sh
su - postgres -c "${POSTGRES} -D ${DATADIR} -c config_file=${CONF} ${LOCALONLY} &"

# wait for postgres to come up
until su - postgres -c "psql -l"; do
  sleep 1
done
echo "postgres ready"
}
