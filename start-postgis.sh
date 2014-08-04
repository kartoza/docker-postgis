#!/bin/bash

DATADIR="/var/lib/postgresql/9.3/main"
CONF="/etc/postgresql/9.3/main/postgresql.conf"
POSTGRES="/usr/lib/postgresql/9.3/bin/postgres"
INITDB="/usr/lib/postgresql/9.3/bin/initdb"
SQLDIR="/usr/share/postgresql/9.3/contrib/postgis-2.1/"

# test if DATADIR is existent
if [ ! -d $DATADIR ]; then
  echo "Creating Postgres data at $DATADIR"
  mkdir -p $DATADIR
fi

# Note that $USERNAME and $PASS below are optional paramters that can be passed
# via docker run e.g.
#docker run --name="postgis" -e USERNAME=qgis -e PASS=qgis -d -v 
#/var/docker-data/postgres-dat:/var/lib/postgresql -t qgis/postgis:6

# If you dont specify a user/password in docker run, we will generate one
# here and create a user called 'docker' to go with it.


# test if DATADIR has content
if [ ! "$(ls -A $DATADIR)" ]; then

  # No content yet - first time pg is being run!


  # /etc/ssl/private can't be accessed from within container for some reason
  # (@andrewgodwin says it's something AUFS related)  - taken from https://github.com/orchardup/docker-postgresql/blob/master/Dockerfile
  mkdir /etc/ssl/private-copy
  mv /etc/ssl/private/* /etc/ssl/private-copy/
  rm -r /etc/ssl/private
  mv /etc/ssl/private-copy /etc/ssl/private
  chmod -R 0700 /etc/ssl/private 
  chown -R postgres /etc/ssl/private
 
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

  # Initialise db

  echo "Initializing Postgres Database at $DATADIR"
  chown -R postgres $DATADIR
  su postgres sh -c "$INITDB $DATADIR"
fi

# Make sure we have a user set up
if [ -z "$USERNAME" ]; then
  USERNAME=postgis
fi  
if [ -z "$PASS" ]; then
  PASS=postgis
  #PASS=`pwgen -c -n -1 12`
fi  
# redirect user/pass into a file so we can echo it into
# docker logs when container starts
# so that we can tell user their password
echo "postgresql user: $USERNAME" > /PGPASSWORD.txt
echo "postgresql password: $PASS" >> /PGPASSWORD.txt
su postgres sh -c "$POSTGRES --single -D $DATADIR -c config_file=$CONF" <<< "CREATE USER $USERNAME WITH SUPERUSER ENCRYPTED PASSWORD '$PASS';"

trap "echo \"Sending SIGTERM to postgres\"; killall -s SIGTERM postgres" SIGTERM

su postgres sh -c "$POSTGRES -D $DATADIR -c config_file=$CONF" &

# Wait for the db to start up before trying to use it....

sleep 10

RESULT=`su postgres sh -c "psql -l" | grep postgis | wc -l`
if [[ $RESULT == '1' ]]
then
    echo 'Postgis Already There'
else
    echo "Postgis is missing, installing now"
    # Note the dockerfile must have put the postgis.sql and spatialrefsys.sql scripts into /root/
    # We use template0 since we want t different encoding to template1
    echo "Creating template postgis"
    su postgres sh -c "createdb template_postgis -E UTF8 -T template0"
    set -x
    echo "Enabling template_postgis as a template"
    su postgres sh -c "psql template0 -c 'UPDATE pg_database SET datistemplate = TRUE WHERE datname = \'template_postgis\';'"
    echo "Loading postgis.sql"
    su postgres sh -c "psql template_postgis -f $SQLDIR/postgis.sql"
    set +x
    echo "Loading spatial_ref_sys.sql"
    su postgres sh -c "psql template_postgis -f $SQLDIR/spatial_ref_sys.sql"

    # Needed when importing old dumps using e.g ndims for constraints
    echo "Loading legacy sql"
    su postgres sh -c "psql template_postgis -f $SQLDIR/legacy_minimal.sql"
    echo "Granting on geometry columns"
    su postgres sh -c "psql template_postgis -c 'GRANT ALL ON geometry_columns TO PUBLIC;'"
    echo "Granting on geography columns"
    su postgres sh -c "psql template_postgis -c 'GRANT ALL ON geography_columns TO PUBLIC;'"
    echo "Granting on spatial ref sys"
    su postgres sh -c "psql template_postgis -c 'GRANT ALL ON spatial_ref_sys TO PUBLIC;'"
    # This should show up in docker logs afterwards
fi
su postgres sh -c "psql -l"

wait $!
