#!/usr/bin/env bash

source /scripts/env-data.sh

# This script will setup new configured user

# Check user already exists

role_check $POSTGRES_USER
su - postgres -c "psql postgres -c \"$COMMAND USER $POSTGRES_USER WITH SUPERUSER ENCRYPTED PASSWORD '$POSTGRES_PASS';\""


role_check $REPLICATION_USER
su - postgres -c "psql postgres -c \"$COMMAND USER $REPLICATION_USER WITH REPLICATION ENCRYPTED PASSWORD '$REPLICATION_PASS';\""

