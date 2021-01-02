#!/usr/bin/env bash

if [[ ${IMAGE_VERSION} =~ [Bb][Uu][Ll][Ll][Ss][Ee][Yy][Ee] ]]; then
  wget http://ftp.br.debian.org/debian/pool/main/g/gdal/libgdal27_3.1.4+dfsg-1+b1_amd64.deb
  dpkg -i libgdal27_3.1.4+dfsg-1+b1_amd64.deb
fi

