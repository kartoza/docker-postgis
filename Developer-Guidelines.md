[![Scenario Tests](https://github.com/kartoza/docker-postgis/actions/workflows/build-latest.yaml/badge.svg?branch=develop&event=push)](https://github.com/kartoza/docker-postgis/actions/workflows/build-latest.yaml)
[![deploy-image](https://github.com/kartoza/docker-postgis/actions/workflows/deploy-image.yaml/badge.svg)](https://github.com/kartoza/docker-postgis/actions/workflows/deploy-image.yaml)

# Table of Contents

- [Table of Contents](#table-of-contents)
- [docker-postgis](#docker-postgis)
  * [Building the image](#building-the-image)
    + [Self build using Repository checkout](#self-build-using-repository-checkout)
    + [Alternative base distributions builds](#alternative-base-distributions-builds)
    + [Locales](#locales)

# docker-postgis

## Building the image

The following convention is used for tagging the images:

> kartoza/postgis:[POSTGRES_MAJOR_VERSION]-[POSTGIS_MAJOR_VERSION].[POSTGIS_MINOR_RELEASE]

So for example:

``kartoza/postgis:18-3.6`` Provides PostgreSQL 18.0, PostGIS 3.6


### Self build using Repository checkout

To build the image yourself do:

```shell
docker build -t kartoza/postgis git://github.com/kartoza/docker-postgis
```

Alternatively clone the repository and build against any preferred branch

```shell
git clone git://github.com/kartoza/docker-postgis
git checkout branch_name
```

Then do:

```shell
docker build -t kartoza/postgis .
```

Or build against a specific PostgreSQL version

```shell
docker build --build-arg POSTGRES_MAJOR_VERSION=13 --build-arg POSTGIS_MAJOR=3 -t kartoza/postgis:POSTGRES_MAJOR_VERSION .
```

### Alternative base distributions builds

There are build args for `DISTRO` (=debian), `IMAGE_VERSION` (=buster) and `IMAGE_VARIANT` (=slim)
which can be used to control the base image used (but it still needs to be Debian based and have
`PostgreSQL` official apt repo).

For example making Ubuntu 20.04 based build (for better arm64 support) Edit the `.env` file to
change the build arguments,

```dotenv
DISTRO=ubuntu 
IMAGE_VERSION=focal 
IMAGE_VARIANT="" 
```

Then run the script

```shell
./build.sh
```

### Locales

By default, the image build will include **all** `locales` to cover any value for `locale` settings
such as 

* `DEFAULT_COLLATION` 
* `DEFAULT_CTYPE` 
* `DEFAULT_ENCODING`

You can use the build argument: `GENERATE_ALL_LOCALE=0`

This will build with the default locate and speed up the build considerably.



