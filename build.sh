#!/usr/bin/env bash
POSTGRES_MAJOR_VERSION=13

cd base_build
./build.sh
cd ..
docker build -t kartoza/postgis:manual-build .
docker build --build-arg DISTRO=debian --build-arg IMAGE_VERSION=bullseye --build-arg IMAGE_VARIANT=slim -t kartoza/postgis:${POSTGRES_MAJOR_VERSION}.1 .
