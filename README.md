# docker-postgis



A simple docker container that runs PostGIS

Visit our page on the docker hub at: https://registry.hub.docker.com/u/kartoza/postgis/

There are a number of other docker postgis containers out there. This one
differentiates itself by:

* provides ssl support out of the box
* connections are restricted to the docker subnet
* template_postgis database template is created for you
* a database 'gis' is created for you so you can use this container 'out of the
  box' when it runs with e.g. QGIS

We will work to add more security features to this container in the future with 
the aim of making a PostGIS image that is ready to be used in a production 
environment (though probably not for heavy load databases).

**Note:** We recommend using ``apt-cacher-ng`` to speed up package fetching -
you should configure the host for it in the provided 71-apt-cacher-ng file.

## Tagged versions

The following convention is used for tagging the images we build:

kartoza/postgis:[postgres_version]-[postgis-version]

So for example:

``kartoza/postgis:9.4-2.1`` Provides PostgreSQL 9.4, PostGIS 2.1

**Note:** We highly recommend that you use tagged versions because
successive minor versions of PostgreSQL write their database clusters
into different database directories - which will cause your database
to appear to be empty if you are using persistent volumes for your
database storage.

## Getting the image

There are various ways to get the image onto your system:


The preferred way (but using most bandwidth for the initial image) is to
get our docker trusted build like this:


```
docker pull kartoza/postgis
```

To build the image yourself without apt-cacher (also consumes more bandwidth
since deb packages need to be refetched each time you build) do:

```
docker build -t kartoza/postgis git://github.com/kartoza/docker-postgis
```

To build with apt-cache (and minimised download requirements) do you need to
clone this repo locally first and modify the contents of 71-apt-cacher-ng to
match your cacher host. Then build using a local url instead of directly from
github.

```
git clone git://github.com/kartoza/docker-postgis
```

Now edit ``71-apt-cacher-ng`` then do:

```
docker build -t kartoza/postgis .
```

## Run


To create a running container do:

```
sudo docker run --name "postgis" -p 25432:5432 -d -t kartoza/postgis
```

You can also use the following environment variables to pass a 
user name and password. 

* -e POSTGRES_USER=<PGUSER> 
* -e POSTGRES_PASS=<PGPASSWORD>

These will be used to create a new superuser with
your preferred credentials. If these are not specified then the postgresql 
user is set to 'docker' with password 'docker'.

## Convenience run script

For convenience we have provided a bash script for running this container
that lets you specify a volume mount point and a username / password 
for the new instance superuser. It takes these options:

```
OPTIONS:
   -h      Show this message
   -n      Container name
   -v      Volume to mount the Postgres cluster into
   -u      Postgres user name (defaults to 'docker')
   -p      Postgres password  (defaults to 'docker')
```

Example usage:

```
./run-postgis-docker.sh -v /tmp/foo/ -n postgis -u foo -p bar

```

## Connect via psql

Connect with psql (make sure you first install postgresql client tools on your
host / client):


```
psql -h localhost -U docker -p 25432 -l
```

**Note:** Default postgresql user is 'docker' with password 'docker'.

You can then go on to use any normal postgresql commands against the container.

Under ubuntu 14.04 the postgresql client can be installed like this:

```
sudo apt-get install postgresql-client-9.3
```


## Storing data on the host rather than the container.


Docker volumes can be used to persist your data.

```
mkdir -p ~/postgres_data
docker run -d -v $HOME/postgres_data:/var/lib/postgresql kartoza/postgis`
```

You need to ensure the ``postgres_data`` directory has sufficient permissions
for the docker process to read / write it.



## Credits

Tim Sutton (tim@kartoza.com)
May 2014
