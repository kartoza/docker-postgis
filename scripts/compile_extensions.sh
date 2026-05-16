#!/usr/bin/env bash

# Compile pointcloud extension
NUM_PROCESSORS=$(nproc)
wget -O- https://github.com/pgpointcloud/pointcloud/archive/master.tar.gz | tar xz && \
cd pointcloud-master && \
./autogen.sh && ./configure && make -j ${NUM_PROCESSORS} && make install && \
cd .. && rm -Rf pointcloud-master


#compile pg_duckdb
if [ "$(echo "${BUILD_PG_DUCKDB}" | tr '[:upper:]' '[:lower:]')" = "true" ]; then \
apt update
apt install -y  \
    libreadline-dev zlib1g-dev flex bison libxml2-dev \
    libxslt-dev libssl-dev libxml2-utils xsltproc pkg-config libc++-dev \
    libc++abi-dev libglib2.0-dev libtinfo6 cmake libstdc++-12-dev \
    liblz4-dev libcurl4-openssl-dev ninja-build libicu-dev git

git clone https://github.com/duckdb/pg_duckdb
cd pg_duckdb
git submodule update --init --recursive
make -j 4 install
cd ..
apt purge -y git;rm -rf pg_duckdb
fi
