[![Scenario Tests](https://github.com/kartoza/docker-postgis/actions/workflows/build-latest.yaml/badge.svg?branch=develop&event=push)](https://github.com/kartoza/docker-postgis/actions/workflows/build-latest.yaml)
[![deploy-image](https://github.com/kartoza/docker-postgis/actions/workflows/deploy-image.yaml/badge.svg)](https://github.com/kartoza/docker-postgis/actions/workflows/deploy-image.yaml)

# Table of Contents

- [Table of Contents](#table-of-contents)
- [docker-postgis](#docker-postgis)
  - [Tagged versions](#tagged-versions)
  - [Getting the image](#getting-the-image)
  - [Building the image](#building-the-image)
    - [Self build using Repository checkout](#self-build-using-repository-checkout)
    - [Alternative base distributions builds](#alternative-base-distributions-builds)
    - [Locales](#locales)
    - [Environment variables](#environment-variables)
      - [Cluster Initializations](#cluster-initializations)
      - [Postgres Encoding](#postgres-encoding)
      - [PostgreSQL extensions](#postgresql-extensions)
      - [Shared preload libraries](#shared-preload-libraries)
      - [Basic configuration](#basic-configuration)
      - [Schema Initialization](#schema-initialization)
      - [Configures archive mode](#configures-archive-mode)
      - [Configure WAL level](#configure-wal-level)
      - [Configure networking](#configure-networking)
      - [Additional configuration](#additional-configuration)
    - [Lockfile](#lockfile)
  - [Docker secrets](#docker-secrets)
  - [Running the container](#running-the-container)
    - [Rootless mode](#rootless-mode)
    - [Using the terminal](#using-the-terminal)
    - [Convenience docker-compose.yml](#convenience-docker-composeyml)
  - [Connect via psql](#connect-via-psql)
  - [Running SQL scripts on container startup.](#running-sql-scripts-on-container-startup)
  - [Storing data on the host rather than the container.](#storing-data-on-the-host-rather-than-the-container)
  - [Postgres SSL setup](#postgres-ssl-setup)
    - [Forced SSL: forced using the shipped snakeoil certificates](#forced-ssl-forced-using-the-shipped-snakeoil-certificates)
    - [Forced SSL with Certificate Exchange: using SSL certificates signed by a certificate authority](#forced-ssl-with-certificate-exchange-using-ssl-certificates-signed-by-a-certificate-authority)
      - [SSL connection inside the docker container using openssl certificates](#ssl-connection-inside-the-docker-container-using-openssl-certificates)
  - [Postgres Replication Setup](#postgres-replication-setup)
    - [Database permissions and password authentication](#database-permissions-and-password-authentication)
    - [Streaming replication](#streaming-replication)
      - [Database permissions](#database-permissions)
      - [Sync changes from master to replicant](#sync-changes-from-master-to-replicant)
      - [Promoting replicant to master](#promoting-replicant-to-master)
      - [Preventing replicant database destroy on restart](#preventing-replicant-database-destroy-on-restart)
    - [Logical replication](#logical-replication)
    - [Docker image versions](#docker-image-versions)
    - [Support](#support)
  - [Credits](#credits)

# docker-postgis

A simple docker container that runs PostGIS

Visit our page on the docker hub at: https://hub.docker.com/r/kartoza/postgis/

There are a number of other docker postgis containers out there. This one
differentiates itself by:

* Provides SSL support out of the box and enforces SSL client connections
* Connections are restricted to the docker subnet
* A default database `gis` is created for you so you can use this container '*out of the box*' when
    it runs with e.g. `QGIS`
* Streaming replication and logical replication support included (turned off by default)
* Ability to create multiple database when starting the container.
* Ability to create multiple schemas when starting the container.  
* Enable multiple extensions in the database when setting it up.
* `Gdal` drivers automatically registered for pg raster.
* Support for out-of-db rasters.

We will work to add more security features to this container in the future with the aim of making a
`PostGIS` image that is ready to be used in a production environment (though probably not for heavy load databases).

There is a nice 'from scratch' tutorial on using this docker image on Alex Urquhart's blog
[here](https://alexurquhart.com/post/set-up-postgis-with-docker/) - if you are just getting started
with `docker`, `PostGIS` and `QGIS`, we recommend that you read it and try out the instructions
specified on the blog.

## Tagged versions

The following convention is used for tagging the images we build:

> kartoza/postgis:[POSTGRES_MAJOR_VERSION]-[POSTGIS_MAJOR_VERSION].[POSTGIS_MINOR_RELEASE]

So for example:

``kartoza/postgis:14-3.1`` Provides PostgreSQL 14.0, PostGIS 3.1

**Note:** We highly recommend that you use tagged versions because successive minor versions of
`PostgreSQL` write their database clusters into different database directories - which will cause
your database to appear to be empty if you are using persistent volumes for your database storage.

## Getting the image

There are various ways to get the image onto your system:

The preferred way (but using most bandwidth for the initial image) is to get our docker trusted
build like this,

```shell
docker pull kartoza/postgis:image_version
```

## Building the image

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
such as `DEFAULT_COLLATION`, `DEFAULT_CTYPE` or `DEFAULT_ENCODING`.

You can use the build argument: `GENERATE_ALL_LOCALE=0`

This will build with the default locate and speed up the build considerably.

### Environment variables

#### Cluster Initializations

With a minimum setup, our image will use an initial cluster located in the
`DATADIR` environment variable. If you want to use persistence, mount these
locations into your `volume/host`. By default, `DATADIR` will point to `/var/lib/postgresql/{major-version}`.
You can instead mount the parent location like this:

```bash
-v data-volume:/var/lib/postgresql
```

This default cluster will be initialized with default locale settings `C.UTF-8`. If, for instance,
you want to create a new cluster with your own settings (not using the default cluster). You need
to specify different empty directory, like this

```shell
-v data-volume:/opt/postgres/data \
-e DATADIR:/opt/postgres/data \
-e DEFAULT_ENCODING="UTF8" \
-e DEFAULT_COLLATION="id_ID.utf8" \
-e DEFAULT_CTYPE="id_ID.utf8" \
-e PASSWORD_AUTHENTICATION="md5" \
-e INITDB_EXTRA_ARGS="<some more initdb command args>" \
-v pgwal-volume:/opt/postgres/pg_wal \
-e POSTGRES_INITDB_WALDIR=/opt/postgres/pg_wal
```

The containers will use above parameters to initialize a new db cluster in the specified directory.
If the directory is not empty, then the initialization parameter will be ignored.

These are some initialization parameters that will only be used to initialize a new cluster. If the
container uses an existing cluster, it is ignored (for example, when the container restarts).

* `DEFAULT_ENCODING`: cluster encoding
* `DEFAULT_COLLATION`: cluster collation
* `DEFAULT_CTYPE`: cluster ctype
* `WAL_SEGSIZE`: WAL segsize option
* `PASSWORD_AUTHENTICATION` : PASSWORD AUTHENTICATION
* `INITDB_EXTRA_ARGS`: extra parameter that will be passed down to `initdb` command
* `POSTGRES_INITDB_WALDIR`: parameter to tell Postgres about the initial waldir location.
**Note:** You must always mount persistent volume to this location. `Postgres` will expect that the
directory will always be available, even though it doesn't need the environment variable anymore.
If you didn't persist this location, Postgres will not be able to find the `pg_wal` directory and
consider the instance to be broken.

In addition to that, we have another parameter: `RECREATE_DATADIR` that can be used to force
database re-initializations. If this parameter is specified as `TRUE` it will act as explicit
consent to delete `DATADIR` and create new db cluster.

* `RECREATE_DATADIR`: Force database re-initialization in the location `DATADIR`

If you used `RECREATE_DATADIR` and successfully created a new cluster. Remember that you should
remove this parameter afterwards. Because, if it was not omitted, it will always recreate new db
cluster after every container restarts.

#### Postgres Encoding

The database cluster is initialized with the following encoding settings

`
-E "UTF8" --lc-collate="en_US.UTF-8" --lc-ctype="en_US.UTF-8"
`

or

`
-E "UTF8" --lc-collate="C.UTF-8" --lc-ctype="C.UTF-8"
`

If you use default `DATADIR` location.

If you need to set up a database cluster with other encoding parameters you need
to pass the environment variables when you initialize the cluster.

* `-e DEFAULT_ENCODING="UTF8"`
* `-e DEFAULT_COLLATION="en_US.UTF-8"`
* `-e DEFAULT_CTYPE="en_US.UTF-8"`

Initializing a new cluster can be done by using different `DATADIR` location and
mounting an empty volume. Or use parameter `RECREATE_DATADIR` to forcefully
delete the current cluster and create a new one. Make sure to remove parameter
`RECREATE_DATADIR` after creating the cluster.

See [the postgres documentation about encoding](https://www.postgresql.org/docs/11/multibyte.html)
for more information.

#### PostgreSQL extensions

The container ships with some default extensions i.e. `postgis,hstore,postgis_topology,postgis_raster,pgrouting`

You can use the environment variable `POSTGRES_MULTIPLE_EXTENSIONS` to activate a subset
or multiple extensions i.e.

```bash
-e POSTGRES_MULTIPLE_EXTENSIONS=postgis,hstore,postgis_topology,postgis_raster,pgrouting`
```

**Note:** Some extensions require extra configurations to get them running properly otherwise
they will cause the container to exit. Users should also consult documentation
relating to that specific extension i.e. [timescaledb](https://github.com/timescale/timescaledb),
[pg_cron](https://github.com/citusdata/pg_cron), [pgrouting](https://pgrouting.org/)

You can also install tagged version of extensions i.e 

```bash
POSTGRES_MULTIPLE_EXTENSIONS=postgis,pgrouting:3.4.0
```

where `pgrouting:3.4.0` The extension name is fixed with the version name with the delimiter being a
colon.

**Note** In some cases, some versions of extensions might not be available for
install. To enable them you can do the following inside the container:
```bash
wget --directory-prefix /usr/share/postgresql/15/extension/ https://raw.githubusercontent.com/postgres/postgres/master/contrib/hstore/hstore--1.1--1.2.sql
```
Then proceed to install it the normal way.

#### Shared preload libraries

Some PostgreSQL extensions require shared_preload_libraries to be specified in the conf files.
Using the environment variable `SHARED_PRELOAD_LIBRARIES` you can pass comma separated values that
correspond to the extensions defined using the environment variable `POSTGRES_MULTIPLE_EXTENSIONS`.

The default libraries that are loaded are `pg_cron,timescaledb` if the image is built with
timescale support otherwise only `pg_cron` is loaded. You can pass the env variable,

```bash
  -e SHARED_PRELOAD_LIBRARIES='pg_cron,timescaledb'
```

**Note** You cannot pass the environment variable `SHARED_PRELOAD_LIBRARIES` without
specifying the PostgreSQL extension that correspond to the `SHARED_PRELOAD_LIBRARIES`.
This will cause the container to exit immediately.

#### Basic configuration

You can use the following environment variables to pass a username, password and/or default
database name(or multiple databases comma separated).

* `-e POSTGRES_USER=<PGUSER>`
* `-e POSTGRES_PASS=<PGPASSWORD>`

  **Note:** You should use a strong passwords. If you are using docker-compose make sure docker can
  interpolate the password. Example using a password with a `$` you will need to escape it ie `$$`

* `-e POSTGRES_DBNAME=<PGDBNAME>`
* `-e SSL_CERT_FILE=/your/own/ssl_cert_file.pem`
* `-e SSL_KEY_FILE=/your/own/ssl_key_file.key`
* `-e SSL_CA_FILE=/your/own/ssl_ca_file.pem`
* `-e DEFAULT_ENCODING="UTF8"`
* `-e DEFAULT_COLLATION="en_US.UTF-8"`
* `-e DEFAULT_CTYPE="en_US.UTF-8"`
* `-e POSTGRES_TEMPLATE_EXTENSIONS=true`
* `-e ACCEPT_TIMESCALE_TUNING=TRUE` Useful to tune PostgreSQL conf based on
[timescaledb-tune](https://github.com/timescale/timescaledb-tune). Defaults to FALSE.
* `-e TIMESCALE_TUNING_PARAMS` Useful to configure none default settings to use when running
`ACCEPT_TIMESCALE_TUNING=TRUE`. This defaults to empty so that we can use the default settings
provided by the `timescaledb-tune`. Example,

    ```bash
    docker run -it --name timescale -e ACCEPT_TIMESCALE_TUNING=TRUE \
      -e POSTGRES_MULTIPLE_EXTENSIONS=postgis,hstore,postgis_topology,postgis_raster,pgrouting,timescaledb \
      -e TIMESCALE_TUNING_PARAMS="-cpus=4" kartoza/postgis:14-3.1
    ```

**Note:** `ACCEPT_TIMESCALE_TUNING` environment variable will overwrite all configurations based
on the timescale configurations

Specifies whether extensions will also be installed in template1 database.

#### Schema Initialization

* `-e SCHEMA_NAME=<PGSCHEMA>`
You can pass a comma separated value of schema names which will be created when the database
  initializes. The default behavior is to create the schema in the first database specified in the
  environment variable `POSTGRES_DBNAME`. If you need to create matching schemas in all the
  databases that will be created you use the environment variable `ALL_DATABASES=TRUE`.

#### Configures archive mode

This image uses the initial PostgreSQL values which disables the archiving option by default. When
`ARCHIVE_MODE` is changed to `on`, the archiving command will copy WAL files to `/opt/archivedir`

[More info: 19.5. Write Ahead Log](https://www.postgresql.org/docs/12/runtime-config-wal.html)

* `-e ARCHIVE_MODE=off`
* `-e ARCHIVE_COMMAND="test ! -f /opt/archivedir/%f && cp %p /opt/archivedir/%f"`
[More info](https://www.postgresql.org/docs/12/continuous-archiving.html#BACKUP-ARCHIVING-WAL)
* `-e ARCHIVE_CLEANUP_COMMAND="pg_archivecleanup /opt/archivedir %r"`
* `-e RESTORE_COMMAND='cp /opt/archivedir/%f "%p"'`

#### Configure WAL level

* `-e WAL_LEVEL=replica`

  [More info](https://www.postgresql.org/docs/12/runtime-config-wal.html). Maximum size to let the
  WAL grow to between automatic WAL checkpoints.

* `-e WAL_SIZE=4GB`
* `-e MIN_WAL_SIZE=2048MB`
* `-e WAL_SEGSIZE=1024`
* `-e MAINTENANCE_WORK_MEM=128MB`

#### Configure networking

You can open up the PG port by using the following environment variable. By default, the container
will allow connections only from the docker private subnet.

* `-e ALLOW_IP_RANGE=<0.0.0.0/0> By default`

Postgres conf is set up to listen to all connections and if a user needs to restrict which IP
address PostgreSQL listens to you can define it with the following environment variable. The
default is set to listen to all connections,

* `-e IP_LIST=<*>`

#### Additional configuration

You can also define any other configuration to add to `extra.conf`, separated by '\n' e.g.:

* `-e EXTRA_CONF="log_destination = 'stderr'\nlogging_collector = on"`

You can alternatively mount an extra  config file into the setting's folder i.e

```shell
docker run --name "postgis" -v /data/extra.conf:/settings/extra.conf -p 25432:5432 -d -t kartoza/postgis
```

The `/setting` folder stores the extra configuration and is copied to the proper directory
 on runtime. The environment variable `EXTRA_CONF_DIR` controls the location of the mounted
 folder.

Then proceed to run the following:

```shell
 docker run --name "postgis" -e EXTRA_CONF_DIR=/etc/conf_settings -v /data:/etc/conf_settings -p 25432:5432 -d -t kartoza/postgis
```

If you want to reinitialize the data directory from scratch, you need to do:

1. Do backup, move data, etc. Any preparations before deleting your data directory.
2. Set environment variables `RECREATE_DATADIR=TRUE`. Restart the service
3. The service will delete your `DATADIR` directory and start re-initializing your data directory from scratch.

### Lockfile

 During container startup, some lockfile are generated which prevent re-initialization of some
 settings. These lockfile are by default stored in the `/settings` folder, but a user can control
 where to store these files using the environment variable `CONF_LOCKFILE_DIR` Example

```shell
-e CONF_LOCKFILE_DIR=/opt/conf_lockfiles \
-v /data/lock_files:/opt/conf_lockfiles 
 -v /data/lock_files:/opt/conf_lockfiles 
-v /data/lock_files:/opt/conf_lockfiles 
 -v /data/lock_files:/opt/conf_lockfiles 
-v /data/lock_files:/opt/conf_lockfiles 
```

 **Note** If you change the environment variable to point to another location when you restart the
 container the settings are reinitialized again.

## Docker secrets

To avoid passing sensitive information in environment variables, `_FILE` can be appended to
some of the variables to read from files present in the container. This is particularly useful
in conjunction with Docker secrets, as passwords can be loaded from `/run/secrets/<secret_name>` e.g.:

* `-e POSTGRES_PASS_FILE=/run/secrets/<pg_pass_secret>`

For more information see [https://docs.docker.com/engine/swarm/secrets/](https://docs.docker.com/engine/swarm/secrets/).

Currently, `POSTGRES_PASS`, `POSTGRES_USER`, `POSTGRES_DB`, `SSL_CERT_FILE`,
`SSL_KEY_FILE`, `SSL_CA_FILE` are supported.

## Running the container

## Rootless mode

You can run the container in rootless mode. This can be achieved by setting the env variable
`RUN_AS_ROOT=false`. By default, this setting is set to `true` to allow the container to run as root for backward 
compatibility with older images.

With `RUN_AS_ROOT=false` you can additionally set the following environment variables to enable you 
to pass user id and group id into the container.

```bash
POSTGRES_UID=1000
POSTGRES_GID=1000
USER=postgresuser
GROUP_NAME=postgresusers
```

If you do not pass the UID and GID, the container will use the defaults specified in the container.

### Using the terminal

To create a running container do:

```shell
docker run --name "postgis" -p 25432:5432 -d -t kartoza/postgis
```

**Note:** If you do not pass the env variable `POSTGRES_PASS` a random password will be generated
and will be visible from the logs or within the container in `/tmp/PGPASSWORD.txt`.

### Convenience docker-compose.yml

For convenience, we  provide a ``docker-compose.yml`` that will run a
copy of the database image and also our related database backup image (see
[https://github.com/kartoza/docker-pg-backup](https://github.com/kartoza/docker-pg-backup)).

The `docker-compose` recipe will expose `PostgreSQL` on port `25432` (to prevent potential conflicts with
any local database instance you may have),

Example usage:

```shell
docker-compose up -d
```

**Note:** The docker-compose recipe above will not persist your data on your local disk, only in a
`docker` volume.

## Connect via psql

Connect with psql (make sure you first install postgresql client tools on your host / client):

```shell
psql -h localhost -U docker -p 25432 -l
```

**Note:** Default postgresql user is 'docker'. If you do not pass the env variable `POSTGRES_PASS`
a random strong password will be generated and can be accessed within the startup logs.

You can then go on to use any normal postgresql commands against the container.

Under ubuntu LTS the postgresql client can be installed like this:

```shell
sudo apt-get install postgresql-client-${POSTGRES_MAJOR_VERSION}
```

Where `POSTGRES_MAJOR_VERSION` corresponds to a specific
PostgreSQL version i.e 12

## Running SQL scripts on container startup.

In some instances users want to run some SQL scripts to populate the database. The environment
variable `POSTGRES_DB` allows us to specify multiple database that can be created on startup. When
running scripts they will only be executed against the first database ie
`POSTGRES_DB=gis,data,sample`. The SQL script will be executed against the `gis` database.
Additionally, a lock file is generated in `/docker-entrypoint-initdb.d`, which will prevent the
scripts from getting executed after the first container startup. Provide
`IGNORE_INIT_HOOK_LOCKFILE=true` to execute the scripts on _every_ container start.

By default, the lockfile is generated in `/docker-entrypoint-initdb.d` but it can be overwritten by
 passing the environment variable `SCRIPTS_LOCKFILE_DIR` which can point to another location i.e

 ```shell
 -e SCRIPTS_LOCKFILE_DIR=/data/ \
 -v /data:/data
 ```

Currently, you can pass `.sql`, `.sql.gz`, `.py` and `.sh` files as mounted volumes.

```shell
docker run -d -v `pwd`/setup-db.sql:/docker-entrypoint-initdb.d/setup-db.sql kartoza/postgis
```

## Storing data on the host rather than the container.

Docker volumes can be used to persist your data.

```shell
mkdir -p ~/postgres_data
docker run -d -v $HOME/postgres_data:/var/lib/postgresql kartoza/postgis
```

You need to ensure the ``postgres_data`` directory has sufficient permissions
for the docker process to read / write it.

## Postgres SSL setup

There are three modalities in which you can work with SSL:

  1. Optional: using the shipped `snakeoil` certificates
  2. Forced SSL: forced using the shipped `snakeoil` certificates
  3. Forced SSL with Certificate Exchange: using SSL certificates signed by a certificate authority

By default, the image is delivered with an unsigned SSL certificate. This helps to have an
encrypted connection to clients and avoid eavesdropping but does not help to mitigate
`Man In The Middle` (MITM) attacks.

You need to provide your own, signed private key to avoid this kind of attacks (and make sure
clients connect with verify-ca or verify-full `sslmode`).

Although SSL is enabled by default, connection to PostgreSQL with other clients i.e (`PSQL` or
`QGIS`) still doesn't enforce SSL encryption. To force SSL connection between clients you need to
use the environment variable,

```shell
FORCE_SSL=TRUE
```

The following example sets up a container with custom ssl private key and certificate:

```shell
docker run -p 25432:5432 -e FORCE_SSL=TRUE -e SSL_DIR="/etc/ssl_certificates" -e SSL_CERT_FILE='/etc/ssl_certificates/fullchain.pem' -e SSL_KEY_FILE='/etc/ssl_certificates/privkey.pem' -e SSL_CA_FILE='/etc/ssl_certificates/root.crt' -v /tmp/postgres/letsencrypt:/etc/ssl_certificates --name ssl -d kartoza/postgis:13-3.1
```

The environment variable `SSL_DIR` allows a user to specify the location
where custom SSL certificates will be located. The environment variable currently
defaults to `SSL_DIR=/ssl_certificates`

See [the postgres documentation about SSL](https://www.postgresql.org/docs/11/libpq-ssl.html#LIBQ-SSL-CERTIFICATES) for more information.

### Forced SSL: forced using the shipped snakeoil certificates

If you are using the default certificates provided by the image when connecting to the database you
will need to set `SSL Mode` to any value besides `verify-full` or `verify-ca`.

The pg_hba.con will have entries like:

```shell
hostssl all all 0.0.0.0/0 scram-sha-256 clientcert=0
```

where `PASSWORD_AUTHENTICATION=scram-sha-256` and `ALLOW_IP_RANGE=0.0.0.0/0`

### Forced SSL with Certificate Exchange: using SSL certificates signed by a certificate authority

When setting up the database you need to define the following environment variables.

- SSL_CERT_FILE
- SSL_KEY_FILE
- SSL_CA_FILE

Example:

```shell
docker run -p 5432:5432 -e FORCE_SSL=TRUE -e SSL_CERT_FILE='/ssl_certificates/fullchain.pem' -e SSL_KEY_FILE='/ssl_certificates/privkey.pem' -e SSL_CA_FILE='/ssl_certificates/root.crt' --name ssl -d kartoza/postgis:13-3.1
```

On the host machine where you need to connect to the database you also 
need to copy the `SSL_CA_FILE` file to the location `/home/$user/.postgresql/root.crt`
or define an environment variable pointing to location of the `SSL_CA_FILE`
example: `PGSSLROOTCERT=/etc/letsencrypt/root.crt`

The `pg_hba.conf` will have entries like:

```shell
hostssl all all 0.0.0.0/0 cert
```

where `ALLOW_IP_RANGE=0.0.0.0/0`

#### SSL connection inside the docker container using openssl certificates

Generate the certificates inside the container

```shell
CERT_DIR=/ssl_certificates
mkdir $CERT_DIR
openssl req -x509 -newkey rsa:4096 -keyout ${CERT_DIR}/privkey.pem -out \
      ${CERT_DIR}/fullchain.pem -days 3650 -nodes -sha256 -subj '/CN=localhost'

cp $CERT_DIR/fullchain.pem $CERT_DIR/root.crt
chmod -R 0700 ${CERT_DIR}
chown -R postgres ${CERT_DIR}
```

Set up your ssl config to point to the new location,

```shell
ssl = true
ssl_cert_file = '/ssl_certificates/fullchain.pem'
ssl_key_file = '/ssl_certificates/privkey.pem'
ssl_ca_file = '/ssl_certificates/root.crt' 
```

Then connect to the database using the psql command:

```shell
psql "dbname=gis port=5432 user=docker host=localhost sslmode=verify-full sslcert=/etc/letsencrypt/fullchain.pem sslkey=/etc/letsencrypt/privkey.pem sslrootcert=/etc/letsencrypt/root.crt"
```

## Postgres Replication Setup

The image supports replication out of the box. By default, replication is turned off. The two main
replication methods allowed are,

* Streaming replication
* Logical replication

### Database permissions and password authentication

Replication  uses a dedicated user `REPLICATION_USER`. The role `${REPLICATION_USER}` uses the
default group role `pg_read_all_data`. You can read more about this from the
[PostgreSQL documentation](https://www.postgresql.org/docs/14/predefined-roles.html)

**Note:** When setting up replication you need to specify the password using the environment
variable `REPLICATION_PASS`. If you do not specify it a random strong password will be generated.
This is visible in the startup logs as well as a text file within the container in
`/tmp/REPLPASSWORD.txt`.

### Streaming replication

Replication allows you to maintain two or more synchronized copies of a database, with a single
**master** copy and one or more **replicant** copies. The animation below illustrates this - the
layer with the red boundary is accessed from the master database and the layer with the green fill
is accessed from the replicant database. When edits to the master layer are saved, they are
automatically propagated to the replicant. Note also that the replicant is read-only.

```shell
docker run --name "streaming-replication" -e REPLICATION=true -e WAL_LEVEL='replica' -d -p 25432:5432 kartoza/postgis:14.3.2
```

**Note** If you do not pass the env variable `REPLICATION_PASS` a random password will be generated
and will be visible from the logs or within the container in `/tmp/REPLPASSWORD.txt`

![qgis](https://user-images.githubusercontent.com/178003/37755610-dd3b774a-2dae-11e8-9fa1-4877e2034675.gif)

This image is provided with replication abilities. We can categorize an instance of the container
as `master` or `replicant`. A `master` instance means that a particular container has a role as a
single point of database write. A `replicant` instance means that a particular container will
mirror database content from a designated master. This replication scheme allows us to sync
databases. However, a `replicant` is only for read-only transaction, thus we can't write new data
to it. The whole database cluster will be replicated.

#### Database permissions

Since we are using a role `${REPLICATION_USER}`, we need to ensure that it has access to all
the tables in a particular schema. So if a user adds another schema called `data` to the database
`gis` he also has to update the permission for the user with the following SQL assuming the
`${REPLICATION_USER}` is called replicator,

```sql
ALTER DEFAULT PRIVILEGES IN SCHEMA data GRANT SELECT ON TABLES TO replicator;
```

**Note** You need to set up a strong password for replication otherwise the default password for
`${REPLICATION_USER}` will default to random generated string.

To experiment with the streaming replication abilities, you can see a
[docker-compose.yml](replication_examples/replication/docker-compose.yml). There are several
environment variables that you can set, such as:

Master settings:

- **ALLOW_IP_RANGE**: A `pg_hba.conf` domain format which will allow specified host(s)
  to connect into the container. This is needed to allow the `slave` to connect into `master`, so
  specifically these settings should allow `slave` address. It is also needed to allow clients on
  other hosts to connect to either the slave or the master.
- **REPLICATION_USER** User to initiate streaming replication
- **REPLICATION_PASS** Password for a user with streaming replication role

Slave settings:

- **REPLICATE_FROM**: This should be the domain name or IP address of the `master`
  instance. It can be anything from the docker resolved name like that written in the sample,
  or the IP address of the actual machine where you expose `master`. This is useful to create cross
  machine replication, or cross stack/server.
- **REPLICATE_PORT**: This should be the port number of `master` postgres instance.
  Will default to 5432 (default postgres port), if not specified.
- **DESTROY_DATABASE_ON_RESTART**: Default is `True`. Set to 'False' to prevent this behavior. A
  replicant will always destroy its current database on restart, because it will try to sync again
  from `master` and avoid inconsistencies.
- **PROMOTE_MASTER**: Default false. If set to `true` then the current replicant
  will be promoted to master. In some cases when the `master` container has failed, we might want
  to use our `replicant` as `master` for a while. However, the promoted replicant will break
  consistencies and is not able to revert to replicant anymore, unless it is destroyed and
  re-synced with the new master.
- **REPLICATION_USER** User to initiate streaming replication
- **REPLICATION_PASS** Password for a user with streaming replication role

To run the example streaming_replication, follow these instructions:

Do a manual image build by executing the `build.sh` script

```shell
./build.sh
```

Go into the `replication_examples/streaming_replication` directory and experiment with the
following `Make` command to run both master and slave services.

```shell
make up
```

To shut down services, execute:

```shell
make down
```

To view logs for master and slave respectively, use the following command:

```shell
make master-log
make node-log
```

You can try experiment with several scenarios to see how replication works

#### Sync changes from master to replicant

You can use any postgres database tools to create new tables in master, by connecting using
`POSTGRES_USER` and `POSTGRES_PASS` credentials using exposed port. In the streaming_replication
example, the master database was exposed on port 7777. Or you can do it via command line, by
entering the shell:

```shell
make master-shell
```

Then make any database changes using psql.

After that, you can see that the replicant follows the changes by inspecting the slave database.
You can, again, use database management tools using connection credentials, hostname, and ports for
replicant. Or you can do it via command line, by entering the shell:

```shell
make node-shell
```

Then view your changes using psql.

#### Promoting replicant to master

You will notice that you cannot make changes in replicant, because it is read-only. If somehow you
want to promote it to master, you can specify `PROMOTE_MASTER: 'True'` into slave environment and
set `DESTROY_DATABASE_ON_RESTART: 'False'`.

After this, you can make changes to your replicant, but master and replicant will not be in sync
anymore. This is useful if the replicant needs to take over a failover master. However, it is
recommended to take additional action, such as creating a backup from the slave so a dedicated
master can be created again.

#### Preventing replicant database destroy on restart

You can optionally set `DESTROY_DATABASE_ON_RESTART: 'False'` after successful sync to prevent the
database from being destroyed on restart. With this setting you can shut down your replicant and
restart it later, and it will continue to sync using the existing database (as long as there are no
consistencies conflicts).

However, you should note that this option doesn't mean anything if you didn't persist your database
volume. Because if it is not persisted, then it will be lost on restart because docker will recreate
the container.

### Logical replication

To activate the following you need to use the environment variable

`WAL_LEVEL=logical` to get a running instance like

```shell
docker run --name "logical-replication" -e WAL_LEVEL=logical -d  kartoza/postgis:13.0
```

For a detailed example see the docker-compose in the folder `replication_examples/logical_replication`.

### Docker image versions

All instructions mentioned in the README are valid for the latest running image. Other docker
images might have a few missing features than the ones in the latest image. We mainly do not back
port changes to current stable images that are being used in production. However, if you feel that
some  changes included in the latest tagged version of the image are essential for the previous
image you can cherry-pick the changes against that specific branch and we will test and merge.

### Support

If you require more substantial assistance from [kartoza](https://kartoza.com) (because our work
and interaction on docker-postgis is pro bono), please consider taking out a
[Support Level Agreement](https://kartoza.com/en/shop/product/support).

## Credits

- Tim Sutton (tim@kartoza.com)
- Gavin Fleming (gavin@kartoza.com)
- Rizky Maulana (rizky@kartoza.com)
- Admire Nyakudya (admire@kartoza.com)

April 2022
