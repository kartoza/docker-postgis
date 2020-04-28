#!/usr/bin/env bash

set -e

# backward compatibility with older script locations
source /scripts/env-data.sh || source /env-data.sh

# execute tests
pushd /tests

cat << EOF
Settings used:

DEFAULT_COLLATION: ${DEFAULT_COLLATION}
DEFAULT_CTYPE: ${DEFAULT_CTYPE}
EOF

PGHOST=localhost \
PGDATABASE=gis \
PYTHONPATH=/lib \
  python3 -m unittest -v ${TEST_CLASS}