#!/usr/bin/env bash

source /scripts/env-data.sh

# This script will setup new users using $POSTGRES_USER and $POSTGRES_PASS env variables.



# TODO - Fragile check if a password already contains a comma
SUPER_USERS=$(echo "$POSTGRES_USER" | awk -F "," '{print NF-1}')
SUPER_USERS_PASSWORD=$(echo "$POSTGRES_PASS" | awk -F "," '{print NF-1}')



# check if the number of super users match the number of passwords defined
if [[ ${SUPER_USERS} != ${SUPER_USERS_PASSWORD} ]];then
  echo -e "\e[1;31m Error Number of passwords and users should match  \033[0m"
  exit 1
else
  env_array ${POSTGRES_USER}
  for db_user in "${strarr[@]}"; do
    env_array ${POSTGRES_PASS}
    for db_pass in "${strarr[@]}"; do
      echo -e "\e[32m [Entrypoint] creating superuser \e[1;31m ${db_user}  \033[0m"
      # Check user already exists
      role_check $db_user
      su - postgres -c "psql postgres -c \"$COMMAND USER $db_user WITH SUPERUSER ENCRYPTED PASSWORD '$db_pass';\""
    done
  done
fi



echo "Creating replication user $REPLICATION_USER"
role_check $REPLICATION_USER
su - postgres -c "psql postgres -c \"$COMMAND USER $REPLICATION_USER WITH REPLICATION ENCRYPTED PASSWORD '$REPLICATION_PASS';\""

