#!/usr/bin/env bash

if [[ ! -f .env ]]; then
    echo "Default build arguments don't exists. Creating one from default value."
    cp .example.env .env
fi
source .env

if [[ ${BUILD_TIMESCALE} =~ [Ff][Aa][Ll][Ss][Ee] ]];then
  if [[ $(dpkg -l | grep "docker-compose") > /dev/null ]];then
    docker-compose -f docker-compose.build.yml build postgis-prod
  else
    docker compose -f docker-compose.build.yml build postgis-prod
  fi

else
  if [[ $(dpkg -l | grep "docker-compose") > /dev/null ]];then
  docker-compose -f docker-compose.build-timescale.yml build postgis-prod
  else
  docker compose -f docker-compose.build-timescale.yml build postgis-prod
  fi
fi