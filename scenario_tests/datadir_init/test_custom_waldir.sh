#!/usr/bin/env bash

# exit immediately if test fails
set -e

source ../test-env.sh
if [[ $(dpkg -l | grep "docker-compose") > /dev/null ]];then
    VERSION='docker-compose'
  else
    VERSION='docker compose'
fi

# This test is special
# It is used to check the meta level of the setup.

# Print logs
if [[ -n "${PRINT_TEST_LOGS}" ]]; then
    ${VERSION} logs -f &
fi

# Recreate containers with the same setup as pg-new and pg-default
# Try to make sure that container recreation is successful
echo "### Checking Container Recreation"
${VERSION} down
${VERSION} up -d pg-default pg-new pg-recreate pg-default-gosu pg-new-gosu pg-recreate-gosu

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

# Check the wrong setup must have warned that nested custom pg_wal location
# is prevented
echo "### Checking Error Message on nested pg_wal location"
services=("pg-custom-waldir-wrong" "pg-custom-waldir-wrong-gosu")
${VERSION} up -d pg-custom-waldir-wrong pg-custom-waldir-wrong-gosu

sleep 60

# Loop until we found error message
for service in "${services[@]}"; do
  while true; do
      if [[ -n "$(${VERSION} logs $service | grep 'Error')" && \
          -n "$(${VERSION} logs $service | grep 'POSTGRES_INITDB_WALDIR should not be set to be inside DATADIR or PGDATA.')" ]]; then
          break
      fi
      sleep 5
  done;
done

${VERSION} down

# Check that the correct custom initdb waldir works, twice after container restart.
echo "### Checking custom POSTGRES_INITDB_WALDIR should work"
services=("pg-custom-waldir-correct" "pg-custom-waldir-correct-gosu")
for service in "${services[@]}"; do
  for ((i=1;i<=2;i++)); do
      echo "attempt $i"
      ${VERSION} up -d $service
      sleep 60
      until ${VERSION} exec -T $service pg_isready; do
          sleep 5
          echo "Wait service to be ready"
      done;
      echo "Execute test for $service"
      ${VERSION} exec -T $service /bin/bash /tests/test.sh
      ${VERSION} down
  done
done

# Check that if the variable POSTGRES_INITBD_WALDIR doesn't match with pg_wal symlink,
# then give warning, but proceeds if the the mount is still correct
echo "### Checking raise warning if custom POSTGRES_INITDB_WALDIR does not match"
services=("pg-custom-waldir-not-match-1" "pg-custom-waldir-not-match-1-gosu")
${VERSION} up -d pg-custom-waldir-not-match-1 pg-custom-waldir-not-match-1-gosu
sleep 60
# Loop until we found warning message
for service in "${services[@]}"; do
  while true; do
      if [[ -n "$(${VERSION} logs $service | grep 'Warning')" && \
          -n "$(${VERSION} logs $service | grep 'POSTGRES_INITDB_WALDIR is not the same as what pg_wal is pointing to.')" ]]; then
          break
      fi
      sleep 5
  done;
  until ${VERSION} exec -T $service pg_isready; do
      sleep 5
      echo "Wait service to be ready"
  done;
  echo "Execute test for $service"
  ${VERSION} exec -T $service /bin/bash /tests/test.sh
done
${VERSION} down

# Check that if the pg_wal is empty, then something is wrong and we should exit
echo "### Checking Error and Exit if pg_wal is empty"
services=("pg-custom-waldir-not-match-2 pg-custom-waldir-not-match-2-gosu")
${VERSION} up -d pg-custom-waldir-not-match-2 pg-custom-waldir-not-match-2-gosu
sleep 60
# Loop until we found warning message
for service in "${services[@]}"; do
  warning_text="Can't proceed because \"/opt/mypostgis/data/pg_wal\" directory is empty."
  while true; do
      if [[ -n "$(${VERSION} logs $service | grep 'Error')" && \
          -n "$(${VERSION} logs $service | grep "$warning_text")" ]]; then
          break
      fi
      sleep 5
  done;
done

${VERSION} down -v
