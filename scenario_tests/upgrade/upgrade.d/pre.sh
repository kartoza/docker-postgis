#!/usr/bin/env bash

echo "Pre-upgrade hook script."
apt -y install postgresql-11-cron postgresql-12-cron
touch /tmp/pre.lock
