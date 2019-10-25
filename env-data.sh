#!/usr/bin/env bash

DATADIR="/var/lib/postgresql/11/main"
ROOT_CONF="/etc/postgresql/11/main"
PG_ENV="$ROOT_CONF/environment"
CONF="$ROOT_CONF/postgresql.conf"
WAL_ARCHIVE="/opt/archivedir"
RECOVERY_CONF="$ROOT_CONF/recovery.conf"
POSTGRES="/usr/lib/postgresql/11/bin/postgres"
INITDB="/usr/lib/postgresql/11/bin/initdb"
SQLDIR="/usr/share/postgresql/11/contrib/postgis-2.5/"
SETVARS="POSTGIS_ENABLE_OUTDB_RASTERS=1 POSTGIS_GDAL_ENABLED_DRIVERS=ENABLE_ALL"
LOCALONLY="-c listen_addresses='127.0.0.1'"
PG_BASEBACKUP="/usr/bin/pg_basebackup"
PROMOTE_FILE="/tmp/pg_promote_master"
PGSTAT_TMP="/var/run/postgresql/"
PG_PID="/var/run/postgresql/11-main.pid"


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
  POSTGRES_MULTIPLE_EXTENSIONS='postgis,hstore,postgis_topology'
fi

if [ -z "${ALLOW_IP_RANGE}" ]; then
  ALLOW_IP_RANGE='0.0.0.0/0'
fi
if [ -z "${DEFAULT_ENCODING}" ]; then
  DEFAULT_ENCODING="UTF8"
fi
if [ -z "${DEFAULT_COLLATION}" ]; then
  DEFAULT_COLLATION="en_US.UTF-8"
fi
if [ -z "${DEFAULT_CTYPE}" ]; then
  DEFAULT_CTYPE="en_US.UTF-8"
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
