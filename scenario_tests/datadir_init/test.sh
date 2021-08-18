#!/usr/bin/env bash

# exit immediately if test fails
set -e

source ../test-env.sh

# Run service
docker-compose up -d pg-default pg-new pg-recreate

if [[ -n "${PRINT_TEST_LOGS}" ]]; then
  docker-compose logs -f &
fi

sleep 60

services=("pg-default" "pg-new" "pg-recreate")

for service in "${services[@]}"; do

  # Execute tests
  until docker-compose exec -T $service pg_isready; do
    sleep 5
    echo "Wait service to be ready"
  done;
  echo "Execute test for $service"
  docker-compose exec -T $service /bin/bash /tests/test.sh

done

# special meta test to check the setup
bash ./test_custom_waldir.sh

docker-compose down -v
