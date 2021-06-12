#!/usr/bin/env bash

# exit immediately if test fails
set -e

source ../test-env.sh

# Run service
docker-compose up -d

if [[ -n "${PRINT_TEST_LOGS}" ]]; then
  docker-compose logs -f &
fi

sleep 30

# Preparing master cluster
until docker-compose exec -T pg-master pg_isready; do
  sleep 30
done;

# Execute tests
docker-compose exec -T pg-master /bin/bash /tests/test_master.sh

# Preparing node cluster
until docker-compose exec -T pg-node pg_isready; do
  sleep 30
done;

# Execute tests
docker-compose exec -T pg-node /bin/bash /tests/test_node.sh

docker-compose down -v
