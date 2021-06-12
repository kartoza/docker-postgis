#!/usr/bin/env bash

# exit immediately if test fails
set -e

source ../test-env.sh

# Run service
docker-compose up -d

if [[ -n "${PRINT_TEST_LOGS}" ]]; then
  docker-compose logs -f &
fi

sleep 60

# Preparing publisher cluster
until docker-compose exec -T pg-publisher pg_isready; do
  sleep 1
done;

# Execute tests
docker-compose exec -T pg-publisher /bin/bash /tests/test_publisher.sh

# Preparing node cluster
until docker-compose exec -T pg-subscriber pg_isready; do
  sleep 1
done;

# Execute tests
docker-compose exec -T pg-subscriber /bin/bash /tests/test_subscriber.sh

docker-compose down -v
