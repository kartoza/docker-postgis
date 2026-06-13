#!/usr/bin/env bash

# exit immediately if test fails
set -e

source ../test-env.sh

# Run service
determine_compose_version

${VERSION} up -d

if [[ -n "${PRINT_TEST_LOGS}" ]]; then
  ${VERSION} logs -f &
fi



services=("pg" "pg-new" "pg-gosu" "pg-new-gosu")

for service in "${services[@]}"; do

  # Execute tests
  wait_for_postgres $service
  echo "Execute test for $service"
  run_tests "$service"

done

${VERSION} down -v
