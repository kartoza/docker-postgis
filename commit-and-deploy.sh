#!/bin/bash
# Commit and redeploy the user map container
#
if [ $# -ne 1 ]; then
    echo "Commit and then redeploy the user_map container."
    echo "Usage:"
    echo "$0 <version>"
    echo "e.g.:"
    echo "$0 1.6"
    echo "Will commit the current state of the container as version 1.6"
    echo "and then redeploy it."
    exit 1
fi
VERSION=$1
HOST_DATA_DIR=/var/docker-data/postgres-data
PGUSER=qgis
PGPASS=qgis

IDFILE=/home/timlinux/postgis-current-container.id
ID=`cat $IDFILE`
docker commit $ID qgis/postgis:$VERSION -run='{"Cmd": ["/start.sh"], "PortSpecs": ["5432"], "Hostname": "postgis"}' -author="Tim Sutton <tim@linfiniti.com>"
docker kill $ID
docker rm $ID
rm $IDFILE
if [ ! -d $HOST_DATA_DIR ]
then
    mkdir $HOST_DATA_DIR
fi
CMD="docker run -cidfile="$IDFILE" -name="postgis" -e POSTGRES_USER=$PGUSER -e POSTGRES_PASS=$PGPASS -d -v $HOST_DATA_DIR:/var/lib/postgresql -t qgis/postgis:$VERSION /start.sh"
echo 'Running:'
echo $CMD
eval $CMD
NEWID=`cat $IDFILE`
echo "Postgis has been committed as $1 and redeployed as $NEWID"
docker ps -a | grep $NEWID
echo "If thhere was no pre-existing database, you can access this using"
IPADDRESS=`docker inspect postgis | grep IPAddress | grep -o '[0-9\.]*'`
echo "psql -l -p 5432 -h $IPADDRESS -U $PGUSER"
echo "and password $PGPASS"
