#!/usr/bin/env bash
set -euo pipefail

#TODO change distro when it's updated
DISTRO=trixie
IMAGE_VERSION=trixie
IMAGE_VARIANT=slim
apt-get update
apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    gnupg \
    jq


install -d /usr/share/postgresql-common/pgdg

curl -fsSL https://www.postgresql.org/media/keys/ACCC4CF8.asc \
    | gpg --dearmor \
    > /usr/share/postgresql-common/pgdg/apt.postgresql.org.gpg

echo "deb [signed-by=/usr/share/postgresql-common/pgdg/apt.postgresql.org.gpg] \
https://apt.postgresql.org/pub/repos/apt ${DISTRO}-pgdg main" \
    > /etc/apt/sources.list.d/pgdg.list

apt-get -qq update

POSTGRES_MAJOR_VERSION=$(apt-cache pkgnames \
  | grep '^postgresql-[0-9]\+$' \
  | sed 's/postgresql-//' \
  | sort -V \
  | tail -1)


POSTGIS_MAJOR_VERSION=$(
  apt-cache policy postgresql-${POSTGRES_MAJOR_VERSION}-postgis-[0-9]\+$ \
    | awk '/Candidate:/ {print $2}' \
    | cut -d. -f1
)

GIS_VER_PROD=$(
  apt-cache policy postgresql-${POSTGRES_MAJOR_VERSION}-postgis-${POSTGIS_MAJOR_VERSION} \
    | awk '/Candidate:/ {print $2}' \
    | sed 's/+.*//' \
    | sed 's/-.*//'
)

PG_VER_PROD=$(apt-cache policy postgresql-${POSTGRES_MAJOR_VERSION} \
      | awk '/Candidate:/ {print $2}' | sed 's/-.*//')

POSTGIS_MINOR_RELEASE=$(echo "$GIS_VER_PROD" | cut -d. -f2)


BASE_IMAGE_SHA=$(curl -s \
  "https://hub.docker.com/v2/repositories/library/debian/tags?page_size=100&name=${IMAGE_VERSION}-${IMAGE_VARIANT}" \
  | jq -r '.results[0].digest')

printf '%s\n' \
    "POSTGRES_MAJOR_VERSION=${POSTGRES_MAJOR_VERSION}" \
    "POSTGIS_MAJOR_VERSION=${POSTGIS_MAJOR_VERSION}" \
    "POSTGIS_MINOR_RELEASE=${POSTGIS_MINOR_RELEASE}" \
    "PG_VER_PROD=${PG_VER_PROD}" \
    "GIS_VER_PROD=${GIS_VER_PROD}" \
    "BASE_IMAGE_DIGEST_SHA=${BASE_IMAGE_SHA}" \
    > /tmp/github_output.txt


