# Add any additional setup tasks here

# These tasks are run as root
CONF="/etc/postgresql/9.3/main/postgresql.conf"

# Restrict subnet to docker private network
echo "host    all             all             172.17.0.0/16               md5" >> /etc/postgresql/9.3/main/pg_hba.conf
# Listen on all ip addresses
echo "listen_addresses = '*'" >> /etc/postgresql/9.3/main/postgresql.conf
echo "port = 5432" >> /etc/postgresql/9.3/main/postgresql.conf

# Enable ssl

echo "ssl = true" >> $CONF
#echo "ssl_ciphers = 'DEFAULT:!LOW:!EXP:!MD5:@STRENGTH' " >> $CONF
#echo "ssl_renegotiation_limit = 512MB "  >> $CONF 
echo "ssl_cert_file = '/etc/ssl/certs/ssl-cert-snakeoil.pem'" >> $CONF 
echo "ssl_key_file = '/etc/ssl/private/ssl-cert-snakeoil.key'" >> $CONF 
#echo "ssl_ca_file = ''                       # (change requires restart)" >> $CONF 
#echo "ssl_crl_file = ''" >> $CONF 
