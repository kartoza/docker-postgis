#!/usr/bin/env bash

# Compile and install PointCloud.
# NOTE: release 1.2.0 would not build against PostgreSQL-12:
# https://github.com/pgpointcloud/pointcloud/issues/248

wget -O- https://github.com/pgpointcloud/pointcloud/archive/master.tar.gz | tar xz && \
  cd pointcloud-master && \
  ./autogen.sh && ./configure && make && make install && \
  cd .. && rm -Rf pointcloud-master

