#!/usr/bin/env bash

source /env-data.sh

# This script will setup default SSL config

# /etc/ssl/private can't be accessed from within container for some reason
# (@andrewgodwin says it's something AUFS related)  - taken from https://github.com/orchardup/docker-postgresql/blob/master/Dockerfile
cp -r /etc/ssl /tmp/ssl-copy/
chmod -R 0700 /etc/ssl
chown -R postgres /tmp/ssl-copy
rm -r /etc/ssl
mv /tmp/ssl-copy /etc/ssl

# Needed under debian, wasnt needed under ubuntu
mkdir -p ${PGSTAT_TMP}
chmod 0777 ${PGSTAT_TMP}
