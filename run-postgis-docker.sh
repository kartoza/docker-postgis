#!/bin/bash
# Commit and redeploy the user map container

usage()
{
cat << EOF
usage: $0 options

This script runs a new docker postgis instance for you.
To get the image run:
docker pull kartoza/postgis


OPTIONS:
   -h      Show this message
   -n      Container name
   -v      Volume to mount the Postgres cluster into
   -l      local port (defaults to 25432)
   -u      Postgres user name (defaults to 'docker')
   -p      Postgres password  (defaults to 'docker')
   -d      database name (defaults to 'gis')
EOF
}

while getopts ":h:n:v:l:u:p:d:" OPTION
do
     case $OPTION in
         n)
             CONTAINER_NAME=${OPTARG}
             ;;
         v)
             VOLUME=${OPTARG}
             ;;
         l)
             LOCALPORT=${optarg}
             ;;
         u)
             PGUSER=${optarg}
             ;;
         p)
             PGPASSWORD=${OPTARG}
             ;;
         p)
             DATADIR=${OPTARG}
             ;;
         *)
             usage
             exit 1
             ;;
     esac
done


if [[ -z $VOLUME ]] || [[ -z $CONTAINER_NAME ]] || [[ -z $PGUSER ]] || [[ -z $PGPASSWORD ]] || [[ -z $DATADIR ]] || [[ -z $LOCALPORT ]]

then
     usage
     exit 1
fi

if [[ ! -z $LOCALPORT]]
then
    LOCALPORT=${LOCALPORT}
else
    LOCALPORT=25432
fi
if [[ ! -z $VOLUME ]]
then
    VOLUME_OPTION="-v ${VOLUME}:/var/lib/postgresql"
else
    VOLUME_OPTION=""
fi

if [ ! -d $VOLUME ]
then
    mkdir $VOLUME
fi
chmod a+w $VOLUME

docker kill ${CONTAINER_NAME}
docker rm ${CONTAINER_NAME}

CMD="docker run --name="${CONTAINER_NAME}" \
        --hostname="${CONTAINER_NAME}" \
        --restart=always \
	-e POSTGRES_USER=${PGUSER} \
	-e POSTGRES_PASS=${PGPASSWORD} \
	-e DATADIR=${DATADIR} \
	-d -t \
        ${VOLUME_OPTION} \
    -p "${LOCALPORT}:5432" \
	kartoza/postgis /start-postgis.sh"

echo 'Running\n'
echo $CMD
eval $CMD

docker ps | grep ${CONTAINER_NAME}

IPADDRESS=`docker inspect ${CONTAINER_NAME} | grep IPAddress | grep -o '[0-9\.]*'`

echo "Connect using:"
echo "psql -l -p 5432 -h $IPADDRESS -U $PGUSER"
echo "and password $PGPASSWORD"
echo
echo "Alternatively link to this container from another to access it"
echo "e.g. docker run -link postgis:pg .....etc"
echo "Will make the connection details to the postgis server available"
echo "in your app container as $PG_PORT_5432_TCP_ADDR (for the ip address)"
echo "and $PG_PORT_5432_TCP_PORT (for the port number)."

