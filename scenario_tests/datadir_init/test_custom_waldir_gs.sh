#!/usr/bin/env bash

# exit immediately if test fails
set -e

source ../test-env.sh

determine_compose_version

# This test is special
# It is used to check the meta level of the setup.

# Print logs
if [[ -n "${PRINT_TEST_LOGS}" ]]; then
    ${VERSION} -f docker-compose-gs.yml logs -f &
fi



# Recreate containers with the same setup as pg-new and pg-default
# Try to make sure that container recreation is successful
echo "### Checking Container Recreation"
${VERSION} -f docker-compose-gs.yml down
${VERSION} -f docker-compose-gs.yml up -d pg-default pg-new pg-recreate

services=("pg-default" "pg-new" "pg-recreate")

for service in "${services[@]}"; do
    # Execute tests
    wait_for_postgres "${service}" "docker-compose-gs.yml"
    echo "Execute test for $service"
    run_tests "$service" "docker-compose-gs.yml"
done

# Check the wrong setup must have warned that nested custom pg_wal location
# is prevented
echo "### Checking Error Message on nested pg_wal location"
service="pg-custom-waldir-wrong"
${VERSION} -f docker-compose-gs.yml up -d $service

# Wait for error message
wait_for_log_message "$service" "Error" "docker-compose-gs.yml"
wait_for_log_message "$service" "POSTGRES_INITDB_WALDIR should not be set to be inside DATADIR or PGDATA." "docker-compose-gs.yml"

${VERSION} -f docker-compose-gs.yml down

# Check that the correct custom initdb waldir works, twice after container restart.
echo "### Checking custom POSTGRES_INITDB_WALDIR should work"
service="pg-custom-waldir-correct"
for ((i=1;i<=2;i++)); do
    echo "attempt $i"
    ${VERSION} -f docker-compose-gs.yml up -d $service

    wait_for_postgres "$service" "docker-compose-gs.yml"

    echo "Execute test for $service"
    run_tests "$service" "docker-compose-gs.yml"
    ${VERSION} -f docker-compose-gs.yml down
done

# Check that if the variable POSTGRES_INITBD_WALDIR doesn't match with pg_wal symlink,
# then give warning, but proceeds if the mount is still correct
echo "### Checking raise warning if custom POSTGRES_INITDB_WALDIR does not match"
service="pg-custom-waldir-not-match-1"
${VERSION} -f docker-compose-gs.yml up -d $service

# Wait for warning message
wait_for_log_message "$service" "Warning" "docker-compose-gs.yml"
wait_for_log_message "$service" "POSTGRES_INITDB_WALDIR is not the same as what pg_wal is pointing to." "docker-compose-gs.yml"

wait_for_postgres "$service" "docker-compose-gs.yml"
echo "Execute test for $service"
run_tests "$service" "docker-compose-gs.yml"
${VERSION} -f docker-compose-gs.yml down

# Check that if the pg_wal is empty, then something is wrong and we should exit
echo "### Checking Error and Exit if pg_wal is empty"
service="pg-custom-waldir-not-match-2"
${VERSION} -f docker-compose-gs.yml up -d $service

# Wait for error message
warning_text="Can't proceed because \"/opt/mypostgis/data/pg_wal\" directory is empty."
wait_for_log_message "$service" "Error" "docker-compose-gs.yml"
wait_for_log_message "$service" "$warning_text" "docker-compose-gs.yml"

${VERSION} -f docker-compose-gs.yml down -v