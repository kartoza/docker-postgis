#!/usr/bin/env bash

source /env-data.sh

SETUP_LOCKFILE="${ROOT_CONF}/.pg_hba.conf.lock"
if [ -f "${SETUP_LOCKFILE}" ]; then
	return 0
fi

# This script will setup pg_hba.conf

# Reconfigure pg_hba if environment settings changed
# cat ${ROOT_CONF}/pg_hba.conf.template > ${ROOT_CONF}/pg_hba.conf


if [[ "${FORCE_SSL}" =~ [Ff][Aa][Ll][Ss][Ee] ]]; then
  PG_CONF_HOST='host'
  CERT_AUTH=${PASSWORD_AUTHENTICATION}
  CLIENT_VERIFY=
else
  # If user has their own cert we default to force auth using cert method
  if  [[ "${SSL_KEY_FILE}" != '/etc/ssl/private/ssl-cert-snakeoil.key' ]]; then
    PG_CONF_HOST='hostssl'
    CERT_AUTH='cert'
    CLIENT_VERIFY=
  else
    # Used when using the default ssl certs
    PG_CONF_HOST='hostssl'
    CERT_AUTH=${PASSWORD_AUTHENTICATION}
    CLIENT_VERIFY='clientcert=0'
  fi

fi

# Restrict subnet to docker private network
echo "$PG_CONF_HOST   all             all             172.0.0.0/8              ${CERT_AUTH}   $CLIENT_VERIFY" >> $ROOT_CONF/pg_hba.conf
# And allow access from DockerToolbox / Boot to docker on OSX
echo "$PG_CONF_HOST    all             all             192.168.0.0/16               ${CERT_AUTH}    $CLIENT_VERIFY" >> $ROOT_CONF/pg_hba.conf

if [ "$ALLOW_IP_RANGE" ]
then
	echo "Add rule to pg_hba: $ALLOW_IP_RANGE"
 	echo "host    all             all             $ALLOW_IP_RANGE              md5" >> $ROOT_CONF/pg_hba.conf
fi

# check password first so we can output the warning before postgres
# messes it up
if [ "$POSTGRES_PASS" ]; then
	pass="PASSWORD '$POSTGRES_PASS'"
	authMethod=${CERT_AUTH}
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
	# add rules to pg_hba.conf to allow replication from all
	echo "Add rule to pg_hba: replication user"
	echo "host replication all 0.0.0.0/0 $authMethod" >> $ROOT_CONF/pg_hba.conf
fi
