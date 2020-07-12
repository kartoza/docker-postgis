#--------- Generic stuff all our Dockerfiles should start with so we get caching ------------
ARG DISTRO=debian
ARG IMAGE_VERSION=buster
ARG IMAGE_VARIANT=-slim
FROM kartoza/postgis:$DISTRO-$IMAGE_VERSION-$IMAGE_VARIANT
MAINTAINER Tim Sutton<tim@kartoza.com>

# Reset ARG for version
ARG IMAGE_VERSION

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
    && apt-get update \
    && apt-get -y --no-install-recommends install postgresql-client-12 \
        postgresql-common postgresql-12 postgresql-12-postgis-3 \
        netcat postgresql-12-ogr-fdw postgresql-12-postgis-3-scripts \
        postgresql-12-cron postgresql-plpython3-12 postgresql-12-pgrouting postgresql-server-dev-12

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
