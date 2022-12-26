#!/usr/bin/env bash

# exit immediately if test fails
set -e

source ../test-env.sh
if [[ $(dpkg -l | grep "docker-compose") > /dev/null ]];then
    VERSION='docker-compose'
  else
    VERSION='docker compose'
fi


# Run service
${VERSION} up -d

if [[ -n "${PRINT_TEST_LOGS}" ]]; then
  ${VERSION} logs -f &
fi

sleep 60

# Preparing publisher cluster
until ${VERSION} exec -T pg-publisher pg_isready; do
  sleep 1
done;

# Execute tests
${VERSION} exec -T pg-publisher /bin/bash /tests/test_publisher.sh

# Preparing node cluster
until ${VERSION} exec -T pg-subscriber pg_isready; do
  sleep 1
done;

# Execute tests
${VERSION} exec -T pg-subscriber /bin/bash /tests/test_subscriber.sh

${VERSION} down -v
