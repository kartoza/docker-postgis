#!/usr/bin/env bash
# For scenario testing purposes

if [[ ! -f .env ]]; then
    echo "Default build arguments don't exists. Creating one from default value."
    cp .example.env .env
fi

if [[ $(dpkg -l | grep "docker-compose") > /dev/null ]];then
  docker-compose -f docker-compose.build.yml build postgis-test
else
  docker compose -f docker-compose.build.yml build postgis-test
fi
