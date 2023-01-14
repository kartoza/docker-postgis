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

# Check user already exists

# TODO - Fragile check if a password already contains a comma
SUPER_USERS=$(echo "$POSTGRES_USER" | awk -F "," '{print NF-1}')
SUPER_USERS_PASSWORD=$(echo "$POSTGRES_PASS" | awk -F "," '{print NF-1}')



# check if the number of super users match the number of passwords defined
if [[ ${SUPER_USERS} != ${SUPER_USERS_PASSWORD} ]];then
  echo -e "\e[1;31m Number of passwords and users should match  \033[0m"
  exit 1
else
  env_array ${POSTGRES_USER}
  for db_user in "${strarr[@]}"; do
    env_array ${POSTGRES_PASS}
    for db_pass in "${strarr[@]}"; do
      echo -e "\e[32m [Entrypoint] creating superuser \e[1;31m ${db_user}  \033[0m"
      RESULT=`su - postgres -c "psql postgres -t -c \"SELECT 1 FROM pg_roles WHERE rolname = '$db_user'\""`
      COMMAND="ALTER"
      if [ -z "$RESULT" ]; then
        COMMAND="CREATE"
      fi
      su - postgres -c "psql postgres -c \"$COMMAND USER $db_user WITH SUPERUSER ENCRYPTED PASSWORD '$db_pass';\""
    done
  done
fi



echo "Creating replication user $REPLICATION_USER"
RESULT_REPLICATION=`su - postgres -c "psql postgres -t -c \"SELECT 1 FROM pg_roles WHERE rolname = '$REPLICATION_USER'\""`
COMMANDS="ALTER"
if [ -z "$RESULT_REPLICATION" ]; then
  COMMANDS="CREATE"
fi
su - postgres -c "psql postgres -c \"$COMMANDS USER $REPLICATION_USER WITH REPLICATION ENCRYPTED PASSWORD '$REPLICATION_PASS';\""
#su - postgres -c "psql postgres -c \"GRANT pg_read_all_data TO $REPLICATION_USER;\""
