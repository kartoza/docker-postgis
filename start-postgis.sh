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

# Note that $USERNAME and $PASS below are passed via docker run e.g.
#docker run -cidfile=/home/timlinux/postgis-current-container.id -name=postgis -e USERNAME=qgis -e PASS=qgis -d -v /var/docker-data/postgres-dat:/var/lib/postgresql -t qgis/postgis:6 /start.sh


# test if DATADIR has content
if [ ! "$(ls -A $DATADIR)" ]; then
  echo "Initializing Postgres Database at $DATADIR"
  chown -R postgres $DATADIR
  su postgres sh -c "$INITDB $DATADIR"
  su postgres sh -c "$POSTGRES --single -D $DATADIR -c config_file=$CONF" <<< "CREATE USER $USERNAME WITH SUPERUSER PASSWORD '$PASS';"
fi

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
    su postgres sh -c "createdb template_postgis -E UTF8 -T template0"
    su postgres sh -c "psql template0 -c 'UPDATE pg_database SET datistemplate = TRUE WHERE datname = \'template_postgis\';'"
    su postgres sh -c "psql template_postgis -f $SQLDIR/postgis.sql"
    su postgres sh -c "psql template_postgis -f $SQLDIR/spatial_ref_sys.sql"
    # Needed when importing old dumps using e.g ndims for constraints
    su postgres sh -c "psql template_postgis -f $SQLDIR/legacy_minimal.sql"
    su postgres sh -c "psql template_postgis -c 'GRANT ALL ON geometry_columns TO PUBLIC;'"
    su postgres sh -c "psql template_postgis -c 'GRANT ALL ON geography_columns TO PUBLIC;'"
    su postgres sh -c "psql template_postgis -c 'GRANT ALL ON spatial_ref_sys TO PUBLIC;'"
    # This should show up in docker logs afterwards
fi
su postgres sh -c "psql -l"

wait $!
