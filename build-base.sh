#!/usr/bin/env bash
# Building an debian base image

docker-compose -f docker-compose.build.yml build postgis-base

