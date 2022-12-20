#!/usr/bin/env bash

# exit immediately if test fails
set -e

source ../test-env.sh

# Run service
docker compose up -d pg-default-md5 pg-new-md5 pg-default-scram

if [[ -n "${PRINT_TEST_LOGS}" ]]; then
  docker compose logs -f &
fi

sleep 60

services=("pg-default-md5" "pg-new-md5" "pg-default-scram")

for service in "${services[@]}"; do

  # Execute tests
  until docker compose exec -T $service pg_isready; do
    sleep 5
    echo "Wait service to be ready"
  done;
  echo "Execute test for $service"
  docker compose exec -T $service /bin/bash /tests/test.sh

done


docker compose down -v
