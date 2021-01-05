#--------- Generic stuff all our Dockerfiles should start with so we get caching ------------
ARG DISTRO=debian
ARG IMAGE_VERSION=bullseye
ARG IMAGE_VARIANT=slim
FROM kartoza/postgis:$DISTRO-$IMAGE_VERSION-$IMAGE_VARIANT-base

MAINTAINER Tim Sutton<tim@kartoza.com>

# Reset ARG for version
ARG IMAGE_VERSION
ARG POSTGRES_MAJOR_VERSION=13
ARG POSTGIS_MAJOR=3
ARG POSTGIS_MINOR_RELEASE=1



RUN set -eux \
    && export DEBIAN_FRONTEND=noninteractive \
    && apt-get update \
    && sh -c "echo \"deb http://apt.postgresql.org/pub/repos/apt/ ${IMAGE_VERSION}-pgdg main\" > /etc/apt/sources.list.d/pgdg.list" \
    && wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc -O- | apt-key add - \
    && apt-get -y --purge autoremove \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* \
    && dpkg-divert --local --rename --add /sbin/initctl


#-------------Application Specific Stuff ----------------------------------------------------

# We add postgis as well to prevent build errors (that we dont see on local builds)
# on docker hub e.g.
# The following packages have unmet dependencies:
RUN set -eux \
    && export DEBIAN_FRONTEND=noninteractive \
    &&  apt-get update \
    && apt-get -y --no-install-recommends install postgresql-client-${POSTGRES_MAJOR_VERSION} \
        postgresql-common postgresql-${POSTGRES_MAJOR_VERSION} \
        postgresql-${POSTGRES_MAJOR_VERSION}-postgis-${POSTGIS_MAJOR} \
        netcat postgresql-${POSTGRES_MAJOR_VERSION}-ogr-fdw \
        postgresql-${POSTGRES_MAJOR_VERSION}-postgis-${POSTGIS_MAJOR}-scripts \
        postgresql-plpython3-${POSTGRES_MAJOR_VERSION} postgresql-${POSTGRES_MAJOR_VERSION}-pgrouting \
        postgresql-server-dev-${POSTGRES_MAJOR_VERSION} postgresql-${POSTGRES_MAJOR_VERSION}-cron


RUN  echo $POSTGRES_MAJOR_VERSION >/tmp/pg_version.txt
RUN  echo $POSTGIS_MAJOR >/tmp/pg_major_version.txt
RUN  echo $POSTGIS_MINOR_RELEASE >/tmp/pg_minor_version.txt
ENV \
    PATH="$PATH:/usr/lib/postgresql/${POSTGRES_MAJOR_VERSION}/bin"
# Compile pointcloud extension

RUN wget -O- https://github.com/pgpointcloud/pointcloud/archive/master.tar.gz | tar xz && \
cd pointcloud-master && \
./autogen.sh && ./configure && make -j 4 && make install && \
cd .. && rm -Rf pointcloud-master

# Cleanup resources
RUN apt-get -y --purge autoremove  \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Open port 5432 so linked containers can see them
EXPOSE 5432

# Copy scripts
ADD scripts /scripts
WORKDIR /scripts
RUN chmod +x *.sh

# Run any additional tasks here that are too tedious to put in
# this dockerfile directly.
RUN set -eux \
    && /scripts/setup.sh

VOLUME /var/lib/postgresql

ENTRYPOINT /scripts/docker-entrypoint.sh