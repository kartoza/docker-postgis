#!/usr/bin/env bash
POSTGRES_MAJOR_VERSION=13
POSTGIS_MINOR_RELEASE=1

pushd base_build
./build.sh
popd
docker build -t kartoza/postgis:manual-build .
docker build --build-arg DISTRO=debian --build-arg IMAGE_VERSION=bullseye --build-arg IMAGE_VARIANT=slim -t kartoza/postgis:${POSTGRES_MAJOR_VERSION}.${POSTGIS_MINOR_RELEASE} .
