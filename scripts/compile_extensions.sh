#!/usr/bin/env bash

# Compile pointcloud extension
wget -O- https://github.com/pgpointcloud/pointcloud/archive/master.tar.gz | tar xz && \
cd pointcloud-master && \
./autogen.sh && ./configure && make -j 4 && make install && \
cd .. && rm -Rf pointcloud-master


