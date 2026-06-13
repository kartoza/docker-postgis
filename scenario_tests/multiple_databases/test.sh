#!/usr/bin/env bash

# exit immediately if test fails
set -e

source ../test-env.sh


determine_compose_version

# Run service as root
${VERSION} up -d pg-database

if [[ -n "${PRINT_TEST_LOGS}" ]]; then
  ${VERSION} logs -f &
fi



# Preparing all databases and all schemas

wait_for_postgres "pg-database"

# Execute tests
${VERSION} exec -T pg-database /bin/bash /tests/test_schemas.sh


${VERSION} down -v


# Run service for pg-schema
${VERSION} up -d pg-schema

if [[ -n "${PRINT_TEST_LOGS}" ]]; then
  ${VERSION} logs -f &
fi



# Preparing all databases and single schema

wait_for_postgres "pg-schema"

# Execute tests
${VERSION} exec -T pg-schema /bin/bash /tests/test_schemas.sh


${VERSION} down -v


# Run service for pg-schema
${VERSION} up -d pg-single-db

if [[ -n "${PRINT_TEST_LOGS}" ]]; then
  ${VERSION} logs -f &
fi



# Preparing all databases and single schema

wait_for_postgres "pg-single-db"

# Execute tests
${VERSION} exec -T pg-single-db /bin/bash /tests/test_schemas.sh


${VERSION} down -v