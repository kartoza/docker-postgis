#!/bin/bash
# Commit and redeploy the user map container

usage()
{
cat << EOF
usage: $0 options

This script runs a new docker postgis instance for you.

OPTIONS:
   -h      Show this message
   -n      Container name
   -v      Volume to mount the Postgres cluster into
   -u      Postgres user name (defaults to 'docker')
   -p      Postgres password  (defaults to 'docker')
EOF
}

while getopts ":h:n:v:u:p:" OPTION
do
     case $OPTION in
         n)
             CONTAINER_NAME=${OPTARG}
             ;;
         v)
             VOLUME=${OPTARG}
             ;;
         u)
             PGUSER=${OPTARG}
             ;;
         p)
             PGPASSWORD=${OPTARG}
             ;;
         *)
             usage
             exit 1
             ;;
     esac
done


if [[ -z $VOLUME ]] || [[ -z $CONTAINER_NAME ]] || [[ -z $PGUSER ]] || [[ -z $PGPASSWORD ]] 
then
     usage
     exit 1
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
	-e USERNAME=${PGUSER} \
	-e PASS=${PGPASSWORD} \
	-d -t \
        ${VOLUME_OPTION} \
	kartoza/postgis /start-postgis.sh"

echo 'Running\n'
echo $CMD
eval $CMD

docker ps | grep ${CONTAINER_NAME}

echo "Connect using:"
echo "psql -l -p 5432 -h $IPADDRESS -U $PGUSER"
echo "and password $PGPASS"
echo
echo "Alternatively link to this container from another to access it"
echo "e.g. docker run -link postgis:pg .....etc"
echo "Will make the connection details to the postgis server available"
echo "in your app container as $PG_PORT_5432_TCP_ADDR (for the ip address)"
echo "and $PG_PORT_5432_TCP_PORT (for the port number)."


