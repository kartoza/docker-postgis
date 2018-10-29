#!/usr/bin/env bash
docker build -t kartoza/postgis:manual-build .
docker tag kartoza/postgis:manual-build kartoza/postgis:9.6-2.4
