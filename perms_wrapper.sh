#!/bin/bash

# needs to be done as root:
chown -R postgres:postgres /var/lib/postgresql

# everything else needs to be done as non-root (i.e. postgres)
sudo -u postgres /start-postgis.sh