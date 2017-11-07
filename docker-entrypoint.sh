#!/usr/bin/env bash

# This script will run as the postgres user due to the Dockerfile USER directive

source /env-data.sh

# /etc/ssl/private can't be accessed from within container for some reason
# (@andrewgodwin says it's something AUFS related)  - taken from https://github.com/orchardup/docker-postgresql/blob/master/Dockerfile
cp -r /etc/ssl /tmp/ssl-copy/
chmod -R 0700 /etc/ssl
chown -R postgres /tmp/ssl-copy
rm -r /etc/ssl
mv /tmp/ssl-copy /etc/ssl

# Needed under debian, wasnt needed under ubuntu
mkdir /var/run/postgresql/9.3-main.pg_stat_tmp
chmod 0777 /var/run/postgresql/9.3-main.pg_stat_tmp

# test if DATADIR is existent
if [ ! -d $DATADIR ]; then
  echo "Creating Postgres data at $DATADIR"
  mkdir -p $DATADIR
fi
# needs to be done as root:
chown -R postgres:postgres $DATADIR

# Note that $POSTGRES_USER and $POSTGRES_PASS below are optional parameters that can be passed
# via docker run e.g.
#docker run --name="postgis" -e POSTGRES_USER=qgis -e POSTGRES_PASS=qgis -d -v
#/var/docker-data/postgres-dat:/var/lib/postgresql -t qgis/postgis:6

# If you dont specify a user/password in docker run, we will generate one
# here and create a user called 'docker' to go with it.

set -e

# test if DATADIR has content
if [[ ! "$(ls -A $DATADIR)" && -z "$REPLICATE_FROM" ]]; then
	# No content yet - first time pg is being run!
	# No Replicate From settings. Assume that this is a master database.
	# Initialise db
	echo "Initializing Postgres Database at $DATADIR"
	#chown -R postgres $DATADIR
	su - postgres -c "$INITDB $DATADIR"
elif [ ! -z "$REPLICATE_FROM" ]; then
	# Adapted from https://github.com/DanielDent/docker-postgres-replication
	# To set up replication
	echo "Destroy initial database, if any."
	rm -rf $DATADIR
	mkdir -p $DATADIR
	chown -R postgres:postgres $DATADIR
	chmod -R 700 $DATADIR

	# No content yet - but this is a slave database
	until ping -c 1 -W 1 ${REPLICATE_FROM}
	do
		echo "Waiting for master to ping..."
		sleep 1s
	done

	echo "Get initial database from master"

	su - postgres -c "echo \"${REPLICATE_FROM}:${REPLICATE_PORT}:*:${POSTGRES_USER}:${POSTGRES_PASS}\" > ~/.pgpass << EOS"
	su - postgres -c "chmod 0600 ~/.pgpass"

	until su - postgres -c "${PG_BASEBACKUP} -X stream -h ${REPLICATE_FROM} -p ${REPLICATE_PORT} -D ${DATADIR} -U ${POSTGRES_USER} -vP -w"
	do
		echo "Waiting for master to connect..."
		sleep 1s
	done
fi

cat $ROOT_CONF/pg_hba.conf.template > $ROOT_CONF/pg_hba.conf

# Custom IP range via docker run -e (https://docs.docker.com/engine/reference/run/#env-environment-variables)
# Usage is: docker run [...] -e ALLOW_IP_RANGE='192.168.0.0/16'
if [ "$ALLOW_IP_RANGE" ]
then
  echo "hostssl    all             all             $ALLOW_IP_RANGE              md5" >> $ROOT_CONF/pg_hba.conf
fi

# redirect user/pass into a file so we can echo it into
# docker logs when container starts
# so that we can tell user their password
if [ -z "$REPLICATE_FROM" ]; then
	# Only create credentials if this is a master database
	echo "postgresql user: $POSTGRES_USER" > /tmp/PGPASSWORD.txt
	echo "postgresql password: $POSTGRES_PASS" >> /tmp/PGPASSWORD.txt
	su - postgres -c "$POSTGRES --single -D $DATADIR -c config_file=$CONF <<< \"CREATE USER $POSTGRES_USER WITH SUPERUSER ENCRYPTED PASSWORD '$POSTGRES_PASS';\""
fi

# check password first so we can output the warning before postgres
# messes it up
if [ "$POSTGRES_PASS" ]; then
	pass="PASSWORD '$POSTGRES_PASS'"
	authMethod=md5
else
	# The - option suppresses leading tabs but *not* spaces. :)
	cat >&2 <<-'EOWARN'
		****************************************************
		WARNING: No password has been set for the database.
				 This will allow anyone with access to the
				 Postgres port to access your database. In
				 Docker's default configuration, this is
				 effectively any other container on the same
				 system.

				 Use "-e POSTGRES_PASS=password" to set
				 it in "docker run".
		****************************************************
	EOWARN

	pass=
	authMethod=trust
fi

if [ -z "$REPLICATE_FROM" ]; then
	# if env not set, then assume this is master instance
	# add rules to pg_hba.conf
	echo "hostssl replication all 0.0.0.0/0 $authMethod" >> $ROOT_CONF/pg_hba.conf
fi

echo
for f in /docker-entrypoint-initdb.d/*; do
	case "$f" in
		*.sh)     echo "$0: running $f"; . "$f" ;;
		*.sql)    echo "$0: running $f"; "${psql[@]}" < "$f"; echo ;;
		*.sql.gz) echo "$0: running $f"; gunzip -c "$f" | "${psql[@]}"; echo ;;
		*)        echo "$0: ignoring $f" ;;
	esac
	echo
done

trap "echo \"Sending SIGTERM to postgres\"; killall -s SIGTERM postgres" SIGTERM

if [ -z "$REPLICATE_FROM" ]; then
	# if this is a master instance, check if postgis is created and fork this process
	su - postgres -c "$POSTGRES -D $DATADIR -c config_file=$CONF &"

	# Wait for the db to start up before trying to use it....

	sleep 10

	RESULT=`su - postgres -c "psql -l | grep postgis | wc -l"`
	echo "Show result $RESULT"
	if [[ ${RESULT} == '1' ]]
	then
		echo 'Postgis Already There'

		if [[ ${HSTORE} == "true" ]]; then
			echo 'HSTORE is only useful when you create the postgis database.'
		fi
		if [[ ${TOPOLOGY} == "true" ]]; then
			echo 'TOPOLOGY is only useful when you create the postgis database.'
		fi
	elif [ -z "$REPLICATE_FROM" ]; then
		echo "Postgis is missing, installing now"
		# Note the dockerfile must have put the postgis.sql and spatialrefsys.sql scripts into /root/
		# We use template0 since we want t different encoding to template1
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
		echo "Loading legacy sql"
		su - postgres -c "psql template_postgis -f $SQLDIR/legacy_minimal.sql"
		su - postgres -c "psql template_postgis -f $SQLDIR/legacy_gist.sql"
		# Create a default db called 'gis' that you can use to get up and running quickly
		# It will be owned by the docker db user
		su - postgres -c "createdb -O $POSTGRES_USER -T template_postgis $POSTGRES_DB"
	fi
	# This should show up in docker logs afterwards
	su - postgres -c "psql -l"

	# Starting logic
	PID=`cat /var/run/postgresql/9.3-main.pid`
	kill -9 ${PID}
fi

# If no arguments passed to entrypoint, then run postgres
if [ $# -eq 0 ];
then
	echo "Postgres initialisation process completed .... restarting in foreground"
	su - postgres -c "$POSTGRES -D $DATADIR -c config_file=$CONF"
fi

if [ "${1:0:1}" = '-' ]; then
	set -- postgres "$@"
fi

if [ "$1" = 'postgres' ]; then
	exec su - postgres "$@"
elif [ ! -z "$1" ]; then
	exec "$1 $@"
fi
