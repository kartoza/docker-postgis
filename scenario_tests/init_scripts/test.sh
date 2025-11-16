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

function executeTests() {
  service=$1

  ${VERSION} up -d ${service}

  if [[ -n "${PRINT_TEST_LOGS}" ]]; then
    ${VERSION} logs -f &
  fi

  # Execute tests
  until ${VERSION} exec -T $service pg_isready; do
    sleep 5
    echo "Wait service to be ready"
  done;
  echo "Execute test for $service"
  ${VERSION} exec -T $service /bin/bash /tests/test.sh

  sleep 60

  ${VERSION} down -v
}

executeTests pg



