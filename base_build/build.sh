#!/usr/bin/env bash
# Building an debian base image

docker build --build-arg DISTRO=debian --build-arg IMAGE_VERSION=bullseye --build-arg IMAGE_VARIANT=slim  -t kartoza/postgis:debian-bullseye-slim-base .
