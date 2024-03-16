#!/usr/bin/env bash

source /scripts/env-data.sh

# This script will setup new configured user

# Check user already exists

role_check "$POSTGRES_USER"
STATEMENT="$COMMAND USER \"$POSTGRES_USER\" WITH SUPERUSER ENCRYPTED PASSWORD '$POSTGRES_PASS';"
echo "$STATEMENT" > /tmp/setup_superuser.sql
su - postgres -c "psql postgres -f /tmp/setup_superuser.sql"
rm /tmp/setup_superuser.sql

role_check "$REPLICATION_USER"
STATEMENT_REPLICATION="$COMMAND USER \"$REPLICATION_USER\" WITH REPLICATION ENCRYPTED PASSWORD '$REPLICATION_PASS';"
echo "$STATEMENT_REPLICATION" > /tmp/setup_replication.sql
su - postgres -c "psql postgres -f /tmp/setup_replication.sql"
rm /tmp/setup_replication.sql

