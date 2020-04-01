#!/usr/bin/env bash

set -e

source /env-data.sh

# prepare requirements
apt -y update;
apt -y install python3-pip
pip3 install -r /lib/utils/requirements.txt

# execute tests
pushd /tests

PGHOST=localhost \
PGDATABASE=gis \
PYTHONPATH=/lib \
  python3 -m unittest -v test_replication.TestReplicationMaster
