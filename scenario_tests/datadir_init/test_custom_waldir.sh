#!/usr/bin/env bash

# exit immediately if test fails
set -e

source ../test-env.sh

determine_compose_version

# This test is special
# It is used to check the meta level of the setup.

# Print logs
if [[ -n "${PRINT_TEST_LOGS}" ]]; then
    ${VERSION} logs -f &
fi


# Recreate containers with the same setup as pg-new and pg-default
# Try to make sure that container recreation is successful
echo "### Checking Container Recreation"
${VERSION} down
${VERSION} up -d pg-local pg-default pg-new pg-recreate

services=("pg-local" "pg-default" "pg-new" "pg-recreate")

for service in "${services[@]}"; do
    # Wait for PostgreSQL to be ready using marker file
    wait_for_postgres $service

    echo "Execute test for $service"
    run_tests "$service"
done

# Check the wrong setup must have warned that nested custom pg_wal location
# is prevented
echo "### Checking Error Message on nested pg_wal location"
service="pg-custom-waldir-wrong"
${VERSION} up -d $service

# Wait for container to exit (should fail)
wait_for_container_status $service

# Check logs for error message
if ${VERSION} logs $service | grep -q "Error" && \
   ${VERSION} logs $service | grep -q "POSTGRES_INITDB_WALDIR should not be set to be inside DATADIR or PGDATA."; then
    echo "Expected error message found"
else
    echo "Expected error message not found"
    exit 1
fi

${VERSION} down

# Check that the correct custom initdb waldir works, twice after container restart.
echo "### Checking custom POSTGRES_INITDB_WALDIR should work"
service="pg-custom-waldir-correct"
for ((i=1;i<=2;i++)); do
    echo "attempt $i"
    ${VERSION} up -d $service
    wait_for_postgres $service
    echo "Execute test for $service"
    run_tests "$service"
    ${VERSION} down
done

# Check that if the variable POSTGRES_INITBD_WALDIR doesn't match with pg_wal symlink,
# then give warning, but proceeds if the mount is still correct
echo "### Checking raise warning if custom POSTGRES_INITDB_WALDIR does not match"
service="pg-custom-waldir-not-match-1"
${VERSION} up -d $service

# Wait for PostgreSQL to be ready (should still start despite warning)
wait_for_postgres $service

# Check logs for warning message
if ${VERSION} logs $service | grep -q "Warning" && \
   ${VERSION} logs $service | grep -q "POSTGRES_INITDB_WALDIR is not the same as what pg_wal is pointing to."; then
    echo "Expected warning message found"
else
    echo "Expected warning message not found"
    exit 1
fi

echo "Execute test for $service"
run_tests "$service"
${VERSION} down

# Check that if the pg_wal is empty, then something is wrong and we should exit
echo "### Checking Error and Exit if pg_wal is empty"
service="pg-custom-waldir-not-match-2"
${VERSION} up -d $service

# Wait for container to exit (should fail)
wait_for_container_status $service

# Check logs for error message
warning_text="Can't proceed because \"/opt/mypostgis/data/pg_wal\" directory is empty."
if ${VERSION} logs $service | grep -q "Error" && \
   ${VERSION} logs $service | grep -q "$warning_text"; then
    echo "Expected error message found"
else
    echo "Expected error message not found"
    exit 1
fi

${VERSION} down -v