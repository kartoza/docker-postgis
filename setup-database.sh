#!/usr/bin/env bash

source /env-data.sh

# This script will setup the necessary folder for database

# test if DATADIR is existent
if [ ! -d ${DATADIR} ]; then
	echo "Creating Postgres data at ${DATADIR}"
	mkdir -p ${DATADIR}
fi


# Set proper permissions
# needs to be done as root:
chown -R postgres:postgres ${DATADIR}


# test if DATADIR has content
if [ ! "$(ls -A ${DATADIR})" ]; then
	# No content yet - first time pg is being run!
	# No Replicate From settings. Assume that this is a master database.
	# Initialise db
	echo "Initializing Postgres Database at ${DATADIR}"
	#chown -R postgres $DATADIR
	su - postgres -c "$INITDB ${DATADIR}"
fi

# test database existing
trap "echo \"Sending SIGTERM to postgres\"; killall -s SIGTERM postgres" SIGTERM
echo "Use modified postgresql.conf for greater speed (spatial and replication)"

cat /tmp/postgresql.conf > ${CONF}

su - postgres -c "${POSTGRES} -D ${DATADIR} -c config_file=${CONF} ${LOCALONLY} &"

# wait for postgres to come up
until su - postgres -c "psql -l"; do
	sleep 1
done
echo "postgres ready"


RESULT=`su - postgres -c "psql -l | grep -w template_postgis | wc -l"`
if [[ ${RESULT} == '1' ]]
then
	echo 'Postgis Already There'

	if [[ ${HSTORE} == "true" ]]; then
		echo 'HSTORE is only useful when you create the postgis database.'
	fi
	if [[ ${TOPOLOGY} == "true" ]]; then
		echo 'TOPOLOGY is only useful when you create the postgis database.'
	fi
else
	echo "Postgis is missing, installing now"
	# Note the dockerfile must have put the postgis.sql and spatialrefsys.sql scripts into /root/
	# We use template0 since we want different encoding to template1
	echo "Creating template postgis"
	su - postgres -c "createdb template_postgis -E UTF8 -T template0"
	echo "Enabling template_postgis as a template"
	CMD="UPDATE pg_database SET datistemplate = TRUE WHERE datname = 'template_postgis';"
	su - postgres -c "psql -c \"$CMD\""
	echo "Loading postgis extension"
	su - postgres -c "psql template_postgis -c 'CREATE EXTENSION postgis;'"

	if [[ ${HSTORE} == "true" ]]
	then
		echo "Enabling hstore in the template"
		su - postgres -c "psql template_postgis -c 'CREATE EXTENSION hstore;'"
	fi
	if [[ ${TOPOLOGY} == "true" ]]
	then
		echo "Enabling topology in the template"
		su - postgres -c "psql template_postgis -c 'CREATE EXTENSION postgis_topology;'"
	fi

	# Needed when importing old dumps using e.g ndims for constraints
	# Ignore error if it doesn't exists
	echo "Loading legacy sql"
	su - postgres -c "psql template_postgis -f ${SQLDIR}/legacy_minimal.sql" || true
	su - postgres -c "psql template_postgis -f ${SQLDIR}/legacy_gist.sql" || true
fi

# Setup user
source /setup-user.sh


# Create a default db called 'gis' or $POSTGRES_DBNAME that you can use to get up and running quickly
# It will be owned by the docker db user

RESULT=`su - postgres -c "psql -l | grep -w ${POSTGRES_DBNAME} | wc -l"`
echo "Check default db exists"
if [[ ! ${RESULT} == '1' ]]; then
	echo "Create default db ${POSTGRES_DBNAME}"
	su - postgres -c "createdb -O ${POSTGRES_USER} -T template_postgis ${POSTGRES_DBNAME}"
else
	echo "${POSTGRES_DBNAME} db already exists"
fi

# This should show up in docker logs afterwards
su - postgres -c "psql -l"

# Kill postgres
PID=`cat $PG_PID`
kill -TERM ${PID}

# Wait for background postgres main process to exit
while [ "$(ls -A ${PG_PID} 2>/dev/null)" ]; do
  sleep 1
done
