#!/usr/bin/env bash

set -e

source /env-data.sh

# execute tests
pushd /tests

PGHOST=localhost \
PGDATABASE=gis \
PYTHONPATH=/lib \
  python3 -m unittest -v test_replication.TestReplicationMaster
