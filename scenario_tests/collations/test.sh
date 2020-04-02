#!/usr/bin/env bash

# exit immediately if test fails
set -e

source ../test-env.sh

# Run service
docker-compose up -d

sleep 5

until docker-compose exec pg pg_isready; do
  sleep 1
done;

# Execute tests
docker-compose exec pg /bin/bash /tests/test.sh

docker-compose down
