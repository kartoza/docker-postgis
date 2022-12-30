#!/usr/bin/env bash

# exit immediately if test fails
set -e

source ../test-env.sh

if [[ $(dpkg -l | grep "docker-compose") > /dev/null ]];then
    VERSION='docker-compose'
  else
    VERSION='docker compose'
fi

# Run service
${VERSION} up -d pg-default pg-new pg-recreate pg-default-gosu pg-new-gosu pg-recreate-gosu

if [[ -n "${PRINT_TEST_LOGS}" ]]; then
  ${VERSION} logs -f &
fi

sleep 60

services=("pg-default" "pg-new" "pg-recreate" "pg-default-gosu" "pg-new-gosu" "pg-recreate-gosu")

for service in "${services[@]}"; do

  # Execute tests
  until ${VERSION} exec -T $service pg_isready; do
    sleep 5
    echo "Wait service to be ready"
  done;
  echo "Execute test for $service"
  ${VERSION} exec -T $service /bin/bash /tests/test.sh

done

# special meta test to check the setup
bash ./test_custom_waldir.sh

${VERSION} down -v
