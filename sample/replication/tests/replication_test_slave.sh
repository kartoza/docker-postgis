#!/bin/sh

. /env-data.sh

set -e

echo "Check slave replication"

# Check table exists in slave

echo "Check table exists"
psql -d ${POSTGRES_DBNAME} -c "\dt" | grep test_replication_table

exit $?
