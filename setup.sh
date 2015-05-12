# Add any additional setup tasks here

# These tasks are run as root
CONF="/etc/postgresql/9.1/main/postgresql.conf"

# /etc/ssl/private can't be accessed from within container for some reason
# (@andrewgodwin says it's something AUFS related)  - taken from https://github.com/orchardup/docker-postgresql/blob/master/Dockerfile
mkdir -p /etc/ssl/private-copy
mv /etc/ssl/private/* /etc/ssl/private-copy/
rm -r /etc/ssl/private
mv /etc/ssl/private-copy /etc/ssl/private
chmod -R 0700 /etc/ssl/private
chown -R postgres /etc/ssl/private

# Restrict subnet to docker private network
echo "host    all             all             0.0.0.0/0                   md5" >> /etc/postgresql/9.1/main/pg_hba.conf
# Listen on all ip addresses
echo "listen_addresses = '*'" >> /etc/postgresql/9.1/main/postgresql.conf
echo "port = 5432" >> /etc/postgresql/9.1/main/postgresql.conf

# Enable ssl

echo "ssl = true" >> $CONF
#echo "ssl_ciphers = 'DEFAULT:!LOW:!EXP:!MD5:@STRENGTH' " >> $CONF
#echo "ssl_renegotiation_limit = 512MB "  >> $CONF 
echo "ssl_cert_file = '/etc/ssl/certs/ssl-cert-snakeoil.pem'" >> $CONF 
echo "ssl_key_file = '/etc/ssl/private/ssl-cert-snakeoil.key'" >> $CONF 
#echo "ssl_ca_file = ''                       # (change requires restart)" >> $CONF 
#echo "ssl_crl_file = ''" >> $CONF 
