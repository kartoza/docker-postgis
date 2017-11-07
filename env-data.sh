#!/usr/bin/env bash

DATADIR="/var/lib/postgresql/9.3/main"
ROOT_CONF="/etc/postgresql/9.3/main"
CONF="$ROOT_CONF/postgresql.conf"
RECOVERY_CONF="/etc/postgresql/9.3/main/recovery.conf"
POSTGRES="/usr/lib/postgresql/9.3/bin/postgres"
INITDB="/usr/lib/postgresql/9.3/bin/initdb"
SQLDIR="/usr/share/postgresql/9.3/contrib/postgis-2.1/"
PG_BASEBACKUP="/usr/bin/pg_basebackup"
PROMOTE_FILE="/tmp/pg_promote_master"

# Make sure we have a user set up
if [ -z "$POSTGRES_USER" ]; then
  POSTGRES_USER=docker
fi
if [ -z "$POSTGRES_PASS" ]; then
  POSTGRES_PASS=docker
fi
if [ -z "$POSTGRES_DB" ]; then
  POSTGRES_DB=gis
fi
# Enable hstore and topology by default
if [ -z "$HSTORE" ]; then
  HSTORE=true
fi
if [ -z "$TOPOLOGY" ]; then
  TOPOLOGY=true
fi
# Replication settings
if [ -z "$REPLICATE_PORT" ]; then
  REPLICATE_PORT=5432
fi
if [ -z "$PG_MAX_WAL_SENDERS" ]; then
  PG_MAX_WAL_SENDERS=8
fi
if [ -z "$PG_WAL_KEEP_SEGMENTS" ]; then
  PG_WAL_KEEP_SEGMENTS=8
fi
