#!/usr/bin/env bash

# exit immediately if test fails
set -e

source ../test-env.sh

if [[ $(dpkg -l | grep "docker-compose") > /dev/null ]];then
    VERSION='docker-compose'
  else
    VERSION='docker compose'
fi


# Run service for root user
${VERSION} up -d pg-local pg-default pg-new pg-recreate

if [[ -n "${PRINT_TEST_LOGS}" ]]; then
  ${VERSION} logs -f &
fi

sleep 30

services=("pg-local" "pg-default" "pg-new" "pg-recreate")

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


# Run service for none root user
mkdir default-pg-data-dir

${VERSION} -f docker-compose-gs.yml up -d pg-local pg-default pg-new pg-recreate

if [[ -n "${PRINT_TEST_LOGS}" ]]; then
  ${VERSION} -f docker-compose-gs.yml logs -f &
fi

sleep 30

services=("pg-local" "pg-default" "pg-new" "pg-recreate")

for service in "${services[@]}"; do

  # Execute tests
  until ${VERSION} -f docker-compose-gs.yml exec -T $service pg_isready; do
    sleep 5
    echo "Wait service to be ready"
  done;
  echo "Execute test for $service"
  ${VERSION} -f docker-compose-gs.yml exec -T $service /bin/bash /tests/test.sh

done

# special meta test to check the setup
#bash ./test_custom_waldir_gs.sh

${VERSION} -f docker-compose-gs.yml down -v
