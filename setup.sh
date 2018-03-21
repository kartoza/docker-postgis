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

# Enable ssl

echo "ssl = true" >> $CONF
#echo "ssl_ciphers = 'DEFAULT:!LOW:!EXP:!MD5:@STRENGTH' " >> $CONF
#echo "ssl_renegotiation_limit = 512MB "  >> $CONF
echo "ssl_cert_file = '/etc/ssl/certs/ssl-cert-snakeoil.pem'" >> $CONF
echo "ssl_key_file = '/etc/ssl/private/ssl-cert-snakeoil.key'" >> $CONF
#echo "ssl_ca_file = ''                       # (change requires restart)" >> $CONF
#echo "ssl_crl_file = ''" >> $CONF

# Create backup template for conf
cat $CONF > $CONF.template
cat $ROOT_CONF/pg_hba.conf > $ROOT_CONF/pg_hba.conf.template
