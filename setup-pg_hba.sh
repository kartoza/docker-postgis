#!/usr/bin/env bash

source /env-data.sh

SETUP_LOCKFILE="${ROOT_CONF}/.pg_hba.conf.lock"
if [ -f "${SETUP_LOCKFILE}" ]; then
	return 0
fi

# This script will setup pg_hba.conf

# Reconfigure pg_hba if environment settings changed
cat ${ROOT_CONF}/pg_hba.conf.template > ${ROOT_CONF}/pg_hba.conf

# Custom IP range via docker run -e (https://docs.docker.com/engine/reference/run/#env-environment-variables)
# Usage is: docker run [...] -e ALLOW_IP_RANGE='192.168.0.0/16'
if [[ "$ALLOW_IP_RANGE" ]]
then
	echo "Add rule to pg_hba: $ALLOW_IP_RANGE"
 	echo "host    all             all             $ALLOW_IP_RANGE              md5" >> ${ROOT_CONF}/pg_hba.conf
fi

# check password first so we can output the warning before postgres
# messes it up
if [[ "$POSTGRES_PASS" ]]; then
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

if [[ -z "$REPLICATE_FROM" ]]; then
	# if env not set, then assume this is master instance
	# add rules to pg_hba.conf to allow replication from all
	echo "Add rule to pg_hba: replication ${REPLICATION_USER} "
	echo "host    replication            ${REPLICATION_USER}             ${ALLOW_IP_RANGE}          $authMethod" >> ${ROOT_CONF}/pg_hba.conf
fi

# Put lock file to make sure conf was not reinitialized
touch ${SETUP_LOCKFILE}
