#!/usr/bin/env bash

# exit immediately if test fails
set -e

source ../test-env.sh

# Run service
docker-compose up -d

sleep 5

services=("pg" "pg-new")

for service in $services; do

  # Execute tests
  until docker-compose exec $service pg_isready; do
    sleep 1
  done;
  docker-compose exec $service /bin/bash /tests/test.sh

done
