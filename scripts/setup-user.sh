#!/usr/bin/env bash

source /scripts/env-data.sh

# This script will setup new configured user

# Check user already exists

role_check "$POSTGRES_USER"
role_creation ${POSTGRES_USER} SUPERUSER $POSTGRES_PASS


role_check "$REPLICATION_USER"
role_creation ${REPLICATION_USER} REPLICATION ${REPLICATION_PASS}


