#!/usr/bin/env bash

# exit immediately if test fails
set -e

source ../test-env.sh

# Run service
docker-compose up -d

sleep 30

# Initializing old clusters
until docker-compose exec pg-previous-version pg_isready; do
  sleep 30
done;
docker-compose exec pg-previous-version /bin/bash /tests/test.sh
docker-compose stop pg-previous-version

docker-compose exec pg-new /bin/bash /scripts/cluster-upgrade.sh
docker-compose exec pg-new /bin/bash /tests/test.sh

docker-compose down -v
