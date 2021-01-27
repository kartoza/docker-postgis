#--------- Generic stuff all our Dockerfiles should start with so we get caching ------------
ARG DISTRO=debian
ARG IMAGE_VERSION=bullseye
ARG IMAGE_VARIANT=slim
FROM $DISTRO:$IMAGE_VERSION-$IMAGE_VARIANT
MAINTAINER Tim Sutton<tim@kartoza.com>

# Reset ARG for version
ARG IMAGE_VERSION

RUN apt-get -qq update --fix-missing && apt-get -qq --yes upgrade

RUN set -eux \
    && export DEBIAN_FRONTEND=noninteractive \
    && apt-get update \
    && apt-get -y --no-install-recommends install \
        locales gnupg2 wget ca-certificates rpl pwgen software-properties-common  iputils-ping \
        apt-transport-https curl \
    && dpkg-divert --local --rename --add /sbin/initctl



RUN apt-get -y update; apt-get -y install build-essential autoconf  libxml2-dev zlib1g-dev netcat gdal-bin



# Temporary - PostgreSQL requires this which is not available in bullseye
ADD gdal_install.sh /gdal_install.sh
RUN chmod 0755 /gdal_install.sh;/bin/bash /gdal_install.sh

# Generating locales takes a long time. Utilize caching by runnig it by itself
# early in the build process.

# Generate all locale only on deployment mode build
# Set to empty string to generate only default locale
ARG GENERATE_ALL_LOCALE=1

COPY scripts/locale.gen /etc/locale.gen
RUN set -eux \
    && [[ (! -z "${GENERATE_ALL_LOCALE}") && (! $GENERATE_ALL_LOCALE -eq 0) ]] \
    && /usr/sbin/locale-gen

ENV LANG=en_US.UTF-8 \
    LANGUAGE=en_US:en \
    LC_ALL=en_US.UTF-8
RUN update-locale ${LANG}

# Cleanup resources
RUN apt-get -y --purge autoremove  \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

