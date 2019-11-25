#!/usr/bin/env bash
docker build -t kartoza/postgis:manual-build .
docker build -t kartoza/postgis:12.0 .
