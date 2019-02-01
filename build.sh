#!/usr/bin/env bash
docker build -t kartoza/postgis:manual-build .
docker build -t kartoza/postgis:11.0-2.5 .
