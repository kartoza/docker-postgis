[![Build Status](https://travis-ci.org/kartoza/docker-postgis.svg?branch=develop)](https://travis-ci.org/kartoza/docker-postgis)

# docker-postgis

A docker image that installs all the dependency for building `kartoza/postgis` image variants.

Visit our page on the docker hub at: https://hub.docker.com/r/kartoza/postgis/


#### Alternative base distributions builds

There are build args for `DISTRO` (=debian), `IMAGE_VERSION` (=buster)
and `IMAGE_VARIANT` (=slim) which can be used to control the base image used
(but it still needs to be Debian based and have PostgreSQL official apt repo).

For example making Ubuntu 20.04 based build (for better arm64 support)
First build the base image using the in the folder `base_build`  using the
build script
following instructions from [Kartoza base image builds](https://github.com/kartoza/docker-postgis/tree/postgres-base#alternative-base-distributions-builds)

Then build the `PostGIS base Image` using

```
docker build --build-arg DISTRO=ubuntu --build-arg IMAGE_VERSION=focal --build-arg IMAGE_VARIANT="" -t kartoza/postgis:$DISTRO-$IMAGE_VERSION-$IMAGE_VARIANT-base .
```

#### Locales

By default, the image build will include **all** `locales` to cover any value for `locale` settings such as `DEFAULT_COLLATION`, `DEFAULT_CTYPE` or `DEFAULT_ENCODING`. 

You can safely delete all `locales` except for the ones you need in `scripts/locale.gen`. This will speed up the build considerably.

### Support

If you require more substantial assistance from [kartoza](https://kartoza.com)  (because our work and interaction on docker-postgis is pro bono),
please consider taking out a [Support Level Agreeement](https://kartoza.com/en/shop/product/support) 

## Credits

Tim Sutton (tim@kartoza.com)
Gavin Fleming (gavin@kartoza.com)
Rizky Maulana (rizky@kartoza.com)
Admire Nyakudya (admire@kartoza.com)
December 2020
