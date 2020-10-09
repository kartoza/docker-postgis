#!/usr/bin/env bash
docker build -t kartoza/postgis:manual-build .
docker build -t kartoza/postgis:13.0 .
