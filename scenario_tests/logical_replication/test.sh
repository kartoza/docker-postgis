#!/usr/bin/env bash

# exit immediately if test fails
set -e

source ../test-env.sh


determine_compose_version


# Run service as root
${VERSION} up -d

if [[ -n "${PRINT_TEST_LOGS}" ]]; then
  ${VERSION} logs -f &
fi



# Preparing publisher cluster

wait_for_postgres "pg-publisher"
# Execute tests
${VERSION} exec -T pg-publisher /bin/bash /tests/test_publisher.sh

# Preparing node cluster

wait_for_postgres "pg-subscriber"
# Execute tests
${VERSION} exec -T pg-subscriber /bin/bash /tests/test_subscriber.sh

${VERSION} down -v

# Run the service as none root

${VERSION} -f docker-compose-gs.yml up -d

if [[ -n "${PRINT_TEST_LOGS}" ]]; then
  ${VERSION} -f docker-compose-gs.yml logs -f &
fi



# Preparing publisher cluster

wait_for_postgres "pg-publisher" "docker-compose-gs.yml"


# Execute tests
${VERSION} -f docker-compose-gs.yml exec -T pg-publisher /bin/bash /tests/test_publisher.sh

# Preparing node cluster

wait_for_postgres "pg-subscriber" "docker-compose-gs.yml"

# Execute tests
${VERSION} -f docker-compose-gs.yml exec -T pg-subscriber /bin/bash /tests/test_subscriber.sh

${VERSION} down -v