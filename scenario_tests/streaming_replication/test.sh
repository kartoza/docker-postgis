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

sleep 30

# Preparing master cluster
until ${VERSION} exec -T pg-master pg_isready; do
  sleep 30
done;

# Execute tests
${VERSION} exec -T pg-master /bin/bash /tests/test_master.sh

# Preparing node cluster
until ${VERSION} exec -T pg-node pg_isready; do
  sleep 30
done;

# Execute tests
${VERSION} exec -T pg-node /bin/bash /tests/test_node.sh

${VERSION} down -v
