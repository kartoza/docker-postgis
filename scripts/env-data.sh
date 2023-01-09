#!/usr/bin/env bash
POSTGRES_MAJOR_VERSION=$(cat /tmp/pg_version.txt)
POSTGIS_MAJOR=$(cat /tmp/pg_major_version.txt)
POSTGIS_MINOR_RELEASE=$(cat /tmp/pg_minor_version.txt)
DEFAULT_DATADIR="/var/lib/postgresql/${POSTGRES_MAJOR_VERSION}/main"
# Commented for documentation. You can specify the location of
# pg_wal directory/volume using the following environment variable:
# POSTGRES_INITDB_WALDIR (default value is unset)
DEFAULT_SCRIPTS_LOCKFILE_DIR="/docker-entrypoint.initdb.d"
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
SETVARS="POSTGIS_ENABLE_OUTDB_RASTERS=1 POSTGIS_GDAL_ENABLED_DRIVERS=ENABLE_ALL"
LOCALONLY="-c listen_addresses='127.0.0.1'"
PG_BASEBACKUP="/usr/bin/pg_basebackup"
PROMOTE_FILE="/tmp/pg_promote_master"
NODE_PROMOTION="/usr/lib/postgresql/${POSTGRES_MAJOR_VERSION}/bin/pg_ctl"
PGSTAT_TMP="/var/run/postgresql/"
PG_PID="/var/run/postgresql/${POSTGRES_MAJOR_VERSION}-main.pid"



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

function boolean() {
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
file_env 'POSTGRES_DBNAME'

function create_dir() {
DATA_PATH=$1

if [[ ! -d ${DATA_PATH} ]];
then
    echo "Creating" ${DATA_PATH}  "directory"
    mkdir -p ${DATA_PATH}
fi
}

function generate_random_string() {
  STRING_LENGTH=$1
  random_pass_string=$(cat /dev/urandom | tr -dc '[:alnum:]' | head -c "${STRING_LENGTH}")
  if [[ ! -f /scripts/.pass_${STRING_LENGTH}.txt ]]; then
    echo ${random_pass_string} > /scripts/.pass_${STRING_LENGTH}.txt
  fi
  export RAND=$(cat /scripts/.pass_${STRING_LENGTH}.txt)
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

if [ -z "${MAINTAINANCE_WORKERS}" ]; then
	MAINTAINANCE_WORKERS=2
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

if [ -z "${MAINTAINANCE_WORK_MEM}" ]; then
	MAINTAINANCE_WORK_MEM=128MB
fi


if [ -z "${SSL_CERT_FILE}" ]; then
	SSL_CERT_FILE='/etc/ssl/certs/ssl-cert-snakeoil.pem'
fi

if [ -z "${SSL_KEY_FILE}" ]; then
	SSL_KEY_FILE='/etc/ssl/private/ssl-cert-snakeoil.key'
fi

# SSL mode
function postgres_ssl_setup() {
  if [ -z "${PGSSLMODE}" ]; then
	   PGSSLMODE=require
  fi
  if [[ ${PGSSLMODE} == 'verify-ca' || ${PGSSLMODE} == 'verify-full' ]]; then
      export PARAMS="sslmode=${PGSSLMODE}&sslcert=${SSL_CERT_FILE}&sslkey=${SSL_KEY_FILE}&sslrootcert=${SSL_CA_FILE}"
  elif [[ ${PGSSLMODE} == 'disable' || ${PGSSLMODE} == 'allow' || ${PGSSLMODE} == 'prefer' || ${PGSSLMODE} == 'require' ]]; then
       export PARAMS="sslmode=${PGSSLMODE}"
  fi

}

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

if [ -z "${SHARED_PRELOAD_LIBRARIES}" ]; then
    if [[ $(dpkg -l | grep "timescaledb") > /dev/null ]];then
        SHARED_PRELOAD_LIBRARIES='pg_cron,timescaledb'
    else
        SHARED_PRELOAD_LIBRARIES='pg_cron'
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

list=(`echo ${POSTGRES_DBNAME} | tr ',' ' '`)
arr=(${list})
SINGLE_DB=${arr[0]}

if [ -z "${TIMEZONE}" ]; then
  TIMEZONE='Etc/UTC'
fi

# usable function definitions
function kill_postgres {
  PID=`cat ${PG_PID}`
  kill -TERM ${PID}

  # Wait for background postgres main process to exit
  # wait until PID file gets deleted
  while ls -A ${PG_PID} 2> /dev/null; do
    sleep 1
  done

  return 0
}

function restart_postgres {

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

function entry_point_script {
  SETUP_LOCKFILE="${SCRIPTS_LOCKFILE_DIR}/.entry_point.lock"
  # If lockfile doesn't exists, proceed.
  if [[ ! -f "${SETUP_LOCKFILE}" ]] || [[ "${IGNORE_INIT_HOOK_LOCKFILE}" =~ [Tt][Rr][Uu][Ee] ]]; then
      if find "/docker-entrypoint-initdb.d" -mindepth 1 -print -quit 2>/dev/null | grep -q .; then
          for f in /docker-entrypoint-initdb.d/*; do
          export PGPASSWORD=${POSTGRES_PASS}
          case "$f" in
                *.sql)    echo "$0: running $f";
                  if [[ "${ALL_DATABASES}" =~ [Ff][Aa][Ll][Ss][Ee] ]]; then
                      psql ${SINGLE_DB} -U ${POSTGRES_USER} -p 5432 -h localhost  -f ${f} || true
                  else
                      for db in $(echo ${POSTGRES_DBNAME} | tr ',' ' '); do
                        psql ${db} -U ${POSTGRES_USER} -p 5432 -h localhost  -f ${f} || true
                      done
                  fi;;
                *.sql.gz) echo "$0: running $f";
                  if [[ "${ALL_DATABASES}" =~ [Ff][Aa][Ll][Ss][Ee] ]]; then
                      gunzip < "$f" | psql ${SINGLE_DB} -U ${POSTGRES_USER} -p 5432 -h localhost || true
                  else
                      for db in $(echo ${POSTGRES_DBNAME} | tr ',' ' '); do
                        gunzip < "$f" | psql ${db} -U ${POSTGRES_USER} -p 5432 -h localhost || true
                      done
                  fi;;
                *.sh)     echo "$0: running $f"; . $f || true;;
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

function configure_replication_permissions {

    echo "Setup data permissions"
    echo "----------------------"
    chown -R postgres:postgres $(getent passwd postgres | cut -d: -f6)
        su - postgres -c "echo \"${REPLICATE_FROM}:${REPLICATE_PORT}:*:${REPLICATION_USER}:${REPLICATION_PASS}\" > ~/.pgpass"
        su - postgres -c "chmod 0600 ~/.pgpass"
}

function streaming_replication {
until su - postgres -c "${PG_BASEBACKUP} -X stream -h ${REPLICATE_FROM} -p ${REPLICATE_PORT} -D ${DATADIR} -U ${REPLICATION_USER} -R -vP -w --label=gis_pg_custer"
	do
		echo "Waiting for master to connect..."
		sleep 1s
		if [[ "$(ls -A ${DATADIR})" ]]; then
			echo "Need empty folder. Cleaning directory..."
			rm -rf ${DATADIR}/*
		fi
	done

}

function over_write_conf() {
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

function extension_install() {
  DATABASE=$1
  IFS=':'
  read -a strarr <<< "$ext"
  EXTENSION_NAME=${strarr[0]}
  EXTENSION_VERSION=${strarr[1]}
  if [[ -z ${EXTENSION_VERSION} ]];then
    if [[ ${EXTENSION_NAME} != 'pg_cron' ]]; then
      echo -e "\e[32m [Entrypoint] Enabling extension \e[1;31m ${EXTENSION_NAME} \e[32m in the database : \e[1;31m ${DATABASE} \033[0m"
      psql ${DATABASE} -U ${POSTGRES_USER} -p 5432 -h localhost -c "CREATE EXTENSION IF NOT EXISTS \"${EXTENSION_NAME}\" cascade;"
    fi
  else
    echo -e "\e[32m [Entrypoint] Installing extension \e[1;31m ${EXTENSION_NAME}  \e[32m with version \e[1;31m ${EXTENSION_VERSION} \e[32m in the database : \e[1;31m ${DATABASE} \033[0m"
    if [[ ${EXTENSION_NAME} != 'pg_cron' ]]; then
      psql ${DATABASE} -U ${POSTGRES_USER} -p 5432 -h localhost -c "CREATE EXTENSION IF NOT EXISTS \"${EXTENSION_NAME}\" WITH VERSION '${EXTENSION_VERSION}' cascade;"
    fi
  fi

}