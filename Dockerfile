#--------- Generic stuff all our Dockerfiles should start with so we get caching ------------
FROM debian:stable
MAINTAINER Tim Sutton<tim@kartoza.com>

ARG DEBIAN_FRONTEND=noninteractive

RUN apt-get -y update && \
    apt-get -y install lsb-release wget software-properties-common gnupg2 && \
    sh -c 'echo OS: `lsb_release -cs`'  
RUN sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt/ `lsb_release -cs`-pgdg main" >> /etc/apt/sources.list.d/pgdg.list' && \
    wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add -
RUN apt-get -y update && apt-get -y upgrade && apt-get -y install postgresql-9.6
RUN apt-get -y install postgresql-client-9.6 postgresql-common postgresql-9.6-postgis-2.4 postgresql-9.6-pgrouting netcat

#-------------Application Specific Stuff ----------------------------------------------------

# Open port 5432 so linked containers can see them
EXPOSE 5432

# We will run any commands in this when the container starts
ADD env-data.sh /
ADD docker-entrypoint.sh /
ADD setup-conf.sh /
ADD setup-database.sh /
ADD setup-pg_hba.sh /
ADD setup-replication.sh /
ADD setup-ssl.sh /
ADD setup-user.sh /
RUN chmod +x /*.sh

ENTRYPOINT /docker-entrypoint.sh
