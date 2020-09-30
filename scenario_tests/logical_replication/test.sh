#!/usr/bin/env bash

# exit immediately if test fails
set -e

source ../test-env.sh

# Run service
docker-compose up -d

sleep 5

# Preparing publisher cluster
until docker-compose exec pg-publisher pg_isready; do
  sleep 1
done;

# Execute tests
docker-compose exec pg-publisher /bin/bash /tests/test_publisher.sh

# Preparing node cluster
until docker-compose exec pg-subscriber pg_isready; do
  sleep 1
done;

# Execute tests
docker-compose exec pg-subscriber /bin/bash /tests/test_subscriber.sh

docker-compose down -v
