#!/usr/bin/env bash

if [[ ! -f .env ]]; then
    echo "Default build arguments don't exists. Creating one from default value."
    cp .example.env .env
fi

docker-compose -f docker-compose.build.yml build postgis-prod

#docker-compose -f docker-compose.build-timescale.yml build postgis-prod
