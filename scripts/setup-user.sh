#!/usr/bin/env bash

source /scripts/env-data.sh

# This script will setup new configured user

# Note that $POSTGRES_USER and $POSTGRES_PASS below are optional parameters that can be passed
# via docker run e.g.
#docker run --name="postgis" -e POSTGRES_USER=qgis -e POSTGRES_PASS=qgis -d -v
#/var/docker-data/postgres-dat:/var/lib/postgresql -t qgis/postgis:6

# If you dont specify a user/password in docker run, we will generate one
# here and create a user called 'docker' to go with it.

# Only create credentials if this is a master database
# Slave database will just mirror from master users

echo "$POSTGRES_PASS" >> /tmp/PGPASSWORD.txt
# Check super user already exists
RESULT=`su - postgres -c "psql postgres -t -c \"SELECT 1 FROM pg_roles WHERE rolname = '$POSTGRES_USER'\""`
COMMAND="ALTER"
if [ -z "$RESULT" ]; then
	COMMAND="CREATE"
fi

echo "Creating superuser user $POSTGRES_USER using $PASSWORD_AUTHENTICATION authentication "
if [ PASSWORD_AUTHENTICATION="md5" ]; then
	PG_PASS=$(U=$POSTGRES_USER; P=$(cat /tmp/PGPASSWORD.txt); echo -n md5; echo -n $P$U | md5sum | cut -d' ' -f1)
	su - postgres -c "psql postgres -c \"$COMMAND USER $POSTGRES_USER WITH SUPERUSER  PASSWORD '$PG_PASS';\""
elif [ PASSWORD_AUTHENTICATION="scram-sha-256" ]; then
  PG_PASS=$(U=$POSTGRES_USER; P=$(cat /tmp/PGPASSWORD.txt); echo -n sha256; echo -n $P$U | sha256sum | cut -d' ' -f1)
  su - postgres -c "psql postgres -c \"$COMMAND USER $POSTGRES_USER WITH SUPERUSER PASSWORD  '$PG_PASS';\""
fi

echo "$REPLICATION_PASS" >> /tmp/REPLICATION_PASS.txt

# Check replication user already exists
RESULT_REPLICATION=`su - postgres -c "psql postgres -t -c \"SELECT 1 FROM pg_roles WHERE rolname = '$REPLICATION_USER'\""`
COMMANDS="ALTER"
if [ -z "$RESULT_REPLICATION" ]; then
  COMMANDS="CREATE"
fi

if [ -z "$RESULT" ]; then
	COMMAND="CREATE"
fi

echo "Creating replication user $REPLICATION_USER using $PASSWORD_AUTHENTICATION authentication "
if [ PASSWORD_AUTHENTICATION="md5" ]; then
	REP_PASS=$(U=$REPLICATION_USER; P=$(cat /tmp/REPLICATION_PASS.txt); echo -n md5; echo -n $P$U | md5sum | cut -d' ' -f1)
	su - postgres -c "psql postgres -c \"$COMMANDS USER $REPLICATION_USER WITH REPLICATION  PASSWORD '$REP_PASS';\""
elif [ PASSWORD_AUTHENTICATION="scram-sha-256" ]; then
  REP_PASS=$(U=$REPLICATION_USER; P=$(cat /tmp/REPLICATION_PASS.txt); echo -n sha256; echo -n $P$U | sha256sum | cut -d' ' -f1)
  su - postgres -c "psql postgres -c \"$COMMANDS USER $REPLICATION_USER WITH REPLICATION  PASSWORD '$REP_PASS';\""
fi

rm /tmp/PGPASSWORD.txt /tmp/REPLICATION_PASS.txt