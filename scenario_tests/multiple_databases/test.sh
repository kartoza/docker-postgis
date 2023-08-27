#!/usr/bin/env bash

# exit immediately if test fails
set -e

source ../test-env.sh
if [[ $(dpkg -l | grep "docker-compose") > /dev/null ]];then
    VERSION='docker-compose'
  else
    VERSION='docker compose'
fi


# Run service as root
${VERSION} up -d pg-database

if [[ -n "${PRINT_TEST_LOGS}" ]]; then
  ${VERSION} logs -f &
fi

sleep 30

# Preparing all databases and all schemas
until ${VERSION} exec -T pg-database pg_isready; do
  sleep 1
done;

# Execute tests
${VERSION} exec -T pg-database /bin/bash /tests/test_schemas.sh


${VERSION} down -v


# Run service for pg-schema
${VERSION} up -d pg-schema

if [[ -n "${PRINT_TEST_LOGS}" ]]; then
  ${VERSION} logs -f &
fi

sleep 30

# Preparing all databases and single schema
until ${VERSION} exec -T pg-schema pg_isready; do
  sleep 1
done;

# Execute tests
${VERSION} exec -T pg-schema /bin/bash /tests/test_schemas.sh


${VERSION} down -v
