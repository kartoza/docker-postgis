#--------- Generic stuff all our Dockerfiles should start with so we get caching ------------
ARG DISTRO=debian
ARG IMAGE_VERSION=buster
ARG IMAGE_VARIANT=-slim
FROM $DISTRO:$IMAGE_VERSION$IMAGE_VARIANT
MAINTAINER Tim Sutton<tim@kartoza.com>

RUN set -eux \
    && export DEBIAN_FRONTEND=noninteractive \
    && apt-get update \
    && apt-get -y --no-install-recommends install \
        locales gnupg2 wget ca-certificates rpl pwgen software-properties-common gdal-bin iputils-ping \
    && apt-get -y --purge autoremove \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* \
    && dpkg-divert --local --rename --add /sbin/initctl

# Generating locales takes a long time. Utilize caching by runnig it by itself
# early in the build process.
RUN apt-get -y update; apt-get -y install build-essential autoconf  libxml2-dev zlib1g-dev netcat

COPY scripts/locale.gen /etc/locale.gen
RUN set -eux \
    && /usr/sbin/locale-gen

ENV LANG=en_US.UTF-8 \
    LANGUAGE=en_US:en \
    LC_ALL=en_US.UTF-8
RUN update-locale ${LANG}

# Cleanup resources
RUN apt-get -y --purge autoremove  \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

