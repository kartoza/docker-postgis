#--------- Generic stuff all our Dockerfiles should start with so we get caching ------------
ARG IMAGE_VERSION=buster
ARG IMAGE_VARIANT=-slim
FROM debian:$IMAGE_VERSION$IMAGE_VARIANT
MAINTAINER Tim Sutton<tim@kartoza.com>

# Reset ARG for version
ARG IMAGE_VERSION

RUN set -eux \
    && export DEBIAN_FRONTEND=noninteractive \
    && apt-get update \
    && apt-get -y --no-install-recommends install \
        locales gnupg2 wget ca-certificates rpl pwgen software-properties-common gdal-bin iputils-ping \
    && sh -c "echo \"deb http://apt.postgresql.org/pub/repos/apt/ ${IMAGE_VERSION}-pgdg main\" > /etc/apt/sources.list.d/pgdg.list" \
    && wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc -O- | apt-key add - \
    && apt-get -y --purge autoremove \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* \
    && dpkg-divert --local --rename --add /sbin/initctl

# Generating locales takes a long time. Utilize caching by runnig it by itself
# early in the build process.
COPY locale.gen /etc/locale.gen
RUN set -eux \
    && /usr/sbin/locale-gen

ENV LANG=en_US.UTF-8 \
    LANGUAGE=en_US:en \
    LC_ALL=en_US.UTF-8
RUN update-locale ${LANG}

#-------------Application Specific Stuff ----------------------------------------------------

# We add postgis as well to prevent build errors (that we dont see on local builds)
# on docker hub e.g.
# The following packages have unmet dependencies:
RUN set -eux \
    && export DEBIAN_FRONTEND=noninteractive \
    && apt-get update \
    && apt-get -y  install postgresql-11 \
    && apt-get -y  install netcat postgresql-11-postgis-2.5 postgresql-common \
    && apt-get -y install postgresql-11-pgrouting postgresql-11-ogr-fdw  \
         postgresql-plpython3-11 postgresql-11-cron python3-pip libpq-dev\
    && apt-get -y --purge autoremove  \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

RUN pip3 install psycopg2
# Open port 5432 so linked containers can see them
EXPOSE 5432

# Copy scripts
COPY docker-entrypoint.sh \
     env-data.sh \
     setup.sh \
     setup-conf.sh \
     setup-database.sh \
     setup-pg_hba.sh \
     setup-replication.sh \
     setup-ssl.sh \
     setup-user.sh \
     /

# Run any additional tasks here that are too tedious to put in
# this dockerfile directly.
RUN set -eux \
    && chmod +x /setup.sh \
    && /setup.sh \
    && chmod +x /docker-entrypoint.sh

VOLUME /var/lib/postgresql

ENTRYPOINT /docker-entrypoint.sh