#!/usr/bin/env bash
# Add any additional setup tasks here
chmod 600 /etc/ssl/private/ssl-cert-snakeoil.key

# These tasks are run as root
source /scripts/env-data.sh


# Restrict subnet to docker private network
echo "host    all             all             172.0.0.0/8              ${PASSWORD_AUTHENTICATION}" >> $ROOT_CONF/pg_hba.conf
# And allow access from DockerToolbox / Boot to docker on OSX
echo "host    all             all             192.168.0.0/16               ${PASSWORD_AUTHENTICATION}" >> $ROOT_CONF/pg_hba.conf

# Create backup template for conf
cat $CONF > $CONF.template
cat $ROOT_CONF/pg_hba.conf > $ROOT_CONF/pg_hba.conf.template
