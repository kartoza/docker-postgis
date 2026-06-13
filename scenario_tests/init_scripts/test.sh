#!/usr/bin/env bash

# exit immediately if test fails
set -e

source ../test-env.sh

determine_compose_version

# Run service
${VERSION} up -d ${service}

if [[ -n "${PRINT_TEST_LOGS}" ]]; then
  ${VERSION} logs -f &
fi

# Execute tests
services=("pg")

for service in "${services[@]}"; do

  # Execute tests
  wait_for_postgres $service
  echo "Execute test for $service"
  run_tests "$service"

done

${VERSION} down -v



