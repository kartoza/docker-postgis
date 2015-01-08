#!/bin/bash

# This script will run as the postgres user due to the Dockerfile USER directive

DATADIR="/var/lib/postgresql/9.3/main"
CONF="/etc/postgresql/9.3/main/postgresql.conf"
POSTGRES="/usr/lib/postgresql/9.3/bin/postgres"
INITDB="/usr/lib/postgresql/9.3/bin/initdb"
SQLDIR="/usr/share/postgresql/9.3/contrib/postgis-2.1/"

# /etc/ssl/private can't be accessed from within container for some reason
# (@andrewgodwin says it's something AUFS related)  - taken from https://github.com/orchardup/docker-postgresql/blob/master/Dockerfile
cp -r /etc/ssl /tmp/ssl-copy/
chmod -R 0700 /etc/ssl
chown -R postgres /tmp/ssl-copy
rm -r /etc/ssl
mv /tmp/ssl-copy /etc/ssl


# test if DATADIR is existent
if [ ! -d $DATADIR ]; then
  echo "Creating Postgres data at $DATADIR"
  mkdir -p $DATADIR
fi
# needs to be done as root:
chown -R postgres:postgres $DATADIR

# Note that $USERNAME and $PASS below are optional paramters that can be passed
# via docker run e.g.
#docker run --name="postgis" -e USERNAME=qgis -e PASS=qgis -d -v
#/var/docker-data/postgres-dat:/var/lib/postgresql -t qgis/postgis:6

# If you dont specify a user/password in docker run, we will generate one
# here and create a user called 'docker' to go with it.


# test if DATADIR has content
if [ ! "$(ls -A $DATADIR)" ]; then

  # No content yet - first time pg is being run!
  # Initialise db
  echo "Initializing Postgres Database at $DATADIR"
  #chown -R postgres $DATADIR
  su - postgres -c "$INITDB $DATADIR"
fi

# Make sure we have a user set up
if [ -z "$USERNAME" ]; then
  USERNAME=docker
fi
if [ -z "$PASS" ]; then
  PASS=docker
fi
# redirect user/pass into a file so we can echo it into
# docker logs when container starts
# so that we can tell user their password
echo "postgresql user: $USERNAME" > /tmp/PGPASSWORD.txt
echo "postgresql password: $PASS" >> /tmp/PGPASSWORD.txt
su - postgres -c "$POSTGRES --single -D $DATADIR -c config_file=$CONF <<< \"CREATE USER $USERNAME WITH SUPERUSER ENCRYPTED PASSWORD '$PASS';\""

trap "echo \"Sending SIGTERM to postgres\"; killall -s SIGTERM postgres" SIGTERM

su - postgres -c "$POSTGRES -D $DATADIR -c config_file=$CONF &"

# Wait for the db to start up before trying to use it....

sleep 10

RESULT=`su - postgres -c "psql -l | grep postgis | wc -l"`
if [[ ${RESULT} == '1' ]]
then
    echo 'Postgis Already There'
else
    echo "Postgis is missing, installing now"
    # Note the dockerfile must have put the postgis.sql and spatialrefsys.sql scripts into /root/
    # We use template0 since we want t different encoding to template1
    echo "Creating template postgis"
    su - postgres -c "createdb template_postgis -E UTF8 -T template0"
    echo "Enabling template_postgis as a template"
    CMD="UPDATE pg_database SET datistemplate = TRUE WHERE datname = 'template_postgis';"
    su - postgres -c "$CMD"
    echo "Loading postgis.sql"
    su - postgres -c "psql template_postgis -f $SQLDIR/postgis.sql"
    echo "Loading spatial_ref_sys.sql"
    su - postgres -c "psql template_postgis -f $SQLDIR/spatial_ref_sys.sql"

    # Needed when importing old dumps using e.g ndims for constraints
    echo "Loading legacy sql"
    su - postgres -c "psql template_postgis -f $SQLDIR/legacy_minimal.sql"
    su - postgres -c "psql template_postgis -f $SQLDIR/legacy_gist.sql"
    echo "Granting on geometry columns"
    su - postgres -c "psql template_postgis -c 'GRANT ALL ON geometry_columns TO PUBLIC;'"
    echo "Granting on geography columns"
    su - postgres -c "psql template_postgis -c 'GRANT ALL ON geography_columns TO PUBLIC;'"
    echo "Granting on spatial ref sys"
    su - postgres -c "psql template_postgis -c 'GRANT ALL ON spatial_ref_sys TO PUBLIC;'"
    # Create a default db called 'gis' that you can use to get up and running quickly
    # It will be owned by the docker db user
    su - postgres -c "createdb -O $USERNAME -T template_postgis gis"
fi
# This should show up in docker logs afterwards
su - postgres -c "psql -l"

PID=`cat /var/run/postgresql/9.3-main.pid`
kill -9 ${PID}
echo "Postgres initialisation process completed .... restarting in foreground"
su - postgres -c "$POSTGRES -D $DATADIR -c config_file=$CONF"
