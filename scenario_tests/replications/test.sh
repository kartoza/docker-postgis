#!/usr/bin/env bash

# exit immediately if test fails
set -e

source ../test-env.sh

# Run service
docker-compose up -d

sleep 5

until docker-compose exec pg-master pg_isready; do
  sleep 1
done;

# Execute tests
docker-compose exec pg-master /bin/bash /tests/test_master.sh
docker-compose exec pg-node /bin/bash /tests/test_node.sh

docker-compose down -v
