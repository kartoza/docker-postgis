#!/usr/bin/env bash

# exit immediately if test fails
set -e

source ../test-env.sh

determine_compose_version


# Run service for root user
${VERSION} up -d pg-local pg-default pg-new pg-recreate

if [[ -n "${PRINT_TEST_LOGS}" ]]; then
  ${VERSION} logs -f &
fi



services=("pg-local" "pg-default" "pg-new" "pg-recreate")

for service in "${services[@]}"; do

  # Execute tests

  wait_for_postgres $service
  echo "Execute test for $service"
  run_tests "$service"

done

# special meta test to check the setup
echo "starting wal tests ----------------"
bash ./test_custom_waldir.sh

${VERSION} down -v
echo "completed wal tests ----------------"

# Run service for none root user
mkdir default-pg-data-dir

${VERSION} -f docker-compose-gs.yml up -d pg-local pg-default pg-new pg-recreate

if [[ -n "${PRINT_TEST_LOGS}" ]]; then
  ${VERSION} -f docker-compose-gs.yml logs -f &
fi



services=("pg-local" "pg-default" "pg-new" "pg-recreate")

for service in "${services[@]}"; do

  # Execute tests

  wait_for_postgres $service "docker-compose-gs.yml"
  echo "Execute test for $service"
  run_tests "$service" "docker-compose-gs.yml"

done

# special meta test to check the setup
#bash ./test_custom_waldir_gs.sh

${VERSION} -f docker-compose-gs.yml down -v
