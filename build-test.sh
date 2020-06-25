#!/usr/bin/env bash

./build.sh

docker build -t kartoza/postgis:manual-build -f Dockerfile.test .
