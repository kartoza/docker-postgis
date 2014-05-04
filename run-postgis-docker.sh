#!/bin/bash
# Commit and redeploy the user map container

# Note this script hosts the postgis cluster on the host filesystem
# If you want to use the container with the cluster embedded
# In the container, run it like this:


#
if [ $# -ne 1 ]; then
    echo "Deploy the postgis container."
    echo "Usage:"
    echo "$0 <version>"
    echo "e.g.:"
    echo "$0 2.1"
    echo "Will run the container using tag version 2.1"
    echo "Once it is running see the commit-and-deploy.sh script if you"
    echo "wish to save new snapshots."
    exit 1
fi
VERSION=$1
HOST_DATA_DIR=/var/docker-data/postgres-dat
PGUSER=qgis
PGPASS=qgis

IDFILE=/home/timlinux/postgis-current-container.id

if [ ! -d $HOST_DATA_DIR ]
then
    mkdir $HOST_DATA_DIR
fi
CMD="docker run -cidfile="$IDFILE" -name="postgis" -e USERNAME=$PGUSER -e PASS=$PGPASS -d -v $HOST_DATA_DIR:/var/lib/postgresql -t qgis/postgis:$VERSION /start.sh"
echo 'Running:'
echo $CMD
eval $CMD
NEWID=`cat $IDFILE`
echo "Postgis has been deployed as $NEWID"
docker ps -a | grep $NEWID
echo "If there was no pre-existing database, you can access this using"
IPADDRESS=`docker inspect postgis | grep IPAddress | grep -o '[0-9\.]*'`
echo "psql -l -p 5432 -h $IPADDRESS -U $PGUSER"
echo "and password $PGPASS"
echo
echo "Alternatively link to this container from another to access it"
echo "e.g. docker run -link postgis:pg .....etc"
echo "Will make the connection details to the postgis server available"
echo "in your app container as $PG_PORT_5432_TCP_ADDR (for the ip address)"
echo "and $PG_PORT_5432_TCP_PORT (for the port number)."


