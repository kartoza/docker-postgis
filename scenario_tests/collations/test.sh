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

services=("pg" "pg-new")

for service in "${services[@]}"; do

  # Execute tests
  until docker-compose exec -T $service pg_isready; do
    sleep 30
    echo "Wait service to be ready"
  done;
  echo "Execute test for $service"
  docker-compose exec -T $service /bin/bash /tests/test.sh

done

docker-compose down -v
