#!/usr/bin/env bash

# exit immediately if test fails
set -e

source ../test-env.sh

determine_compose_version

####
# Run service as root user
####
${VERSION} up -d

if [[ -n "${PRINT_TEST_LOGS}" ]]; then
  ${VERSION} logs -f &
fi



# Preparing master cluster
wait_for_postgres "pg-master"

# Execute tests
${VERSION} exec -T pg-master /bin/bash /tests/test_master.sh

# Preparing node cluster

wait_for_postgres "pg-node"

# Execute tests
${VERSION} exec -T pg-node /bin/bash /tests/test_node.sh

${VERSION} down -v

####
# Run service as none root
####
${VERSION} -f docker-compose-gs.yml up -d

if [[ -n "${PRINT_TEST_LOGS}" ]]; then
  ${VERSION} -f docker-compose-gs.yml logs -f &
fi



# Preparing master cluster

wait_for_postgres "pg-master" "docker-compose-gs.yml"

# Execute tests
${VERSION} -f docker-compose-gs.yml exec -T pg-master /bin/bash /tests/test_master.sh

# Preparing node cluster

wait_for_postgres "pg-node" "docker-compose-gs.yml"

# Execute tests
${VERSION} -f docker-compose-gs.yml exec -T pg-node /bin/bash /tests/test_node.sh

${VERSION} -f docker-compose-gs.yml down -v


####
# Run service as root user for node promotion
####
${VERSION} -f docker-compose-root-promote.yml up -d

if [[ -n "${PRINT_TEST_LOGS}" ]]; then
  ${VERSION} -f docker-compose-root-promote.yml logs -f &
fi



# Update env variable
sed -i 's/\(PROMOTE_MASTER: \)false/\1true/'  docker-compose-root-promote.yml

# Bring up node with option to promote node

${VERSION} -f docker-compose-root-promote.yml up -d pg-node

# Preparing node cluster

wait_for_postgres "pg-node" "docker-compose-root-promote.yml"

# Execute tests
${VERSION} -f docker-compose-root-promote.yml exec -T pg-node /bin/bash /tests/test_node_promotion.sh

${VERSION} -f docker-compose-root-promote.yml down -v
sed -i 's/\(PROMOTE_MASTER: \)true/\1false/'  docker-compose-root-promote.yml

####
# Run service as none root user for node promotion
####
${VERSION} -f docker-compose-gs-promote.yml up -d

if [[ -n "${PRINT_TEST_LOGS}" ]]; then
  ${VERSION} -f docker-compose-gs-promote.yml logs -f &
fi



# Update env variable
sed -i 's/\(PROMOTE_MASTER: \)false/\1true/'  docker-compose-gs-promote.yml

# Bring up node with option to promote node

${VERSION} -f docker-compose-gs-promote.yml up -d pg-node

# Preparing node cluster

wait_for_postgres "pg-node" "docker-compose-gs-promote.yml"

# Execute tests
${VERSION} -f docker-compose-gs-promote.yml exec -T pg-node /bin/bash /tests/test_node_promotion.sh

${VERSION} -f docker-compose-gs-promote.yml down -v
sed -i 's/\(PROMOTE_MASTER: \)true/\1false/'  docker-compose-gs-promote.yml