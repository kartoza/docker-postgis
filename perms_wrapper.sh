#!/bin/bash

# /etc/ssl/private can't be accessed from within container for some reason
# (@andrewgodwin says it's something AUFS related)  - taken from https://github.com/orchardup/docker-postgresql/blob/master/Dockerfile
cp -r /etc/ssl /tmp/ssl-copy/
chmod -R 0700 /etc/ssl
chown -R postgres /tmp/ssl-copy
rm -r /etc/ssl
mv /tmp/ssl-copy /etc/ssl

# needs to be done as root:
chown -R postgres:postgres /var/lib/postgresql

# everything else needs to be done as non-root (i.e. postgres)
sudo -u postgres /start-postgis.sh
