#!/bin/sh

. /env-data.sh

set -e

echo "Check master replication"

# Create a new table

echo "Create new table"
psql -d ${POSTGRES_DBNAME} -c "CREATE TABLE test_replication_table ();"

# Check table exists in master

echo "Check table exists"
psql -d ${POSTGRES_DBNAME} -c "\dt" | grep test_replication_table

exit $?
