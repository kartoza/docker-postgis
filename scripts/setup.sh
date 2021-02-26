#!/usr/bin/env bash
# Add any additional setup tasks here
chmod 600 /etc/ssl/private/ssl-cert-snakeoil.key

# These tasks are run as root
source /scripts/env-data.sh

# Create backup template for conf
cat $CONF > $CONF.template
cat $ROOT_CONF/pg_hba.conf > $ROOT_CONF/pg_hba.conf.template
