#!/usr/bin/env bash
# Add any additional setup tasks here
chmod 600 /etc/ssl/private/ssl-cert-snakeoil.key

# These tasks are run as root
source /env-data.sh


# Restrict subnet to docker private network
echo "host    all             all             172.0.0.0/8               md5" >> $ROOT_CONF/pg_hba.conf
# And allow access from DockerToolbox / Boottodocker on OSX
echo "host    all             all             192.168.0.0/16               md5" >> $ROOT_CONF/pg_hba.conf
# Listen on all ip addresses
echo "listen_addresses = '*'" >> $CONF
echo "port = 5432" >> $CONF


# Create backup template for conf
cat $CONF > $CONF.template
cat $ROOT_CONF/pg_hba.conf > $ROOT_CONF/pg_hba.conf.template
