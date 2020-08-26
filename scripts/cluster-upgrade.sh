#!/usr/bin/env bash

set -e

# Variable sanity check
if [[ -z ${PGVERSIONOLD} ]]; then
  echo "Environment variable PGVERSIONOLD is empty."
  echo "It must be set to postgresql version of the old cluster."
fi
if [[ -z ${PGVERSIONNEW} ]]; then
  echo "Environment variable PGVERSIONNEW is empty."
  echo "It must be set to postgresql version of the new cluster."
fi
if [[ -z ${PGDATAOLD} ]]; then
  echo "Environment variable PGDATAOLD is empty."
  echo "It must be set to the location of the old cluster."
fi

if [[ -z ${PGUNIXUSEROLD} ]]; then
  PGUNIXUSEROLD=postgres
fi

if [[ -z ${PGDATANEW} ]]; then
  PGDATANEW=/var/lib/postgresql/12/main
fi

# Inline replace
# Change cluster data_directory
sed -i 's|^data_directory|#data_directory|' /etc/postgresql/11/main/postgresql.conf
echo "data_directory = '${PGDATAOLD}' # Added by cluster-upgrade.sh" >> /etc/postgresql/11/main/postgresql.conf
# Disable ssl, because we won't be able to find the certificate
sed -i 's|^ssl|#ssl|' /etc/postgresql/11/main/postgresql.conf

apt -y update;
# Install all default binary dependencies, which is:
#  - Old postgres + Old postgis
#  - New postgres + Old postgis
#  - New postgres + New Postgis
apt -y install \
  postgresql-${PGVERSIONOLD} postgresql-${PGVERSIONOLD}-postgis-${POSTGISVERSIONOLD} \
  postgresql-${PGVERSIONNEW} postgresql-${PGVERSIONNEW}-postgis-${POSTGISVERSIONNEW} \
  postgresql-${PGVERSIONNEW}-postgis-${POSTGISVERSIONOLD}

# show detected clusters
pg_lsclusters

if [[ -f "/upgrade.d/pre.sh" ]]; then
  echo "Pre upgrade script exists. Executing pre upgrade..."
  source /upgrade.d/pre.sh
fi

# We must change ownership of the data and config so it can be processed by this image
echo "Attempting to change datadir and config permissions to user ${PGUNIXUSEROLD}."
echo "This is an irreversible process."

usermod -aG postgres ${PGUNIXUSEROLD}
chown -R ${PGUNIXUSEROLD}:${PGUNIXUSEROLD} /etc/postgresql/${PGVERSIONOLD} ${PGDATAOLD} /var/log/postgresql /var/run/postgresql

echo "Cluster list after permission change."

pg_lsclusters

# Shutdown default clusters
echo "Shutting down default clusters"
pg_ctlcluster ${PGVERSIONOLD} main stop || true
pg_ctlcluster ${PGVERSIONNEW} main stop || true
# We drop default cluster of the image because we don't need it.
pg_dropcluster ${PGVERSIONNEW} main || true

echo "Perform cluster upgrade"
pg_upgradecluster -v ${PGVERSIONNEW} ${PGVERSIONOLD} main ${PGDATANEW}

# TODO:
# For some reason, pg cron database is not recognized and not upgraded.
# We can only handle it from users perspective

pg_ctlcluster ${PGVERSIONNEW} main start
until pg_isready;
do
  sleep 5;
done;

if [[ "${POSTGISDBNAME}" ]]; then
  echo "Upgrade postgis extensions in database"
  for db in ${POSTGISDBNAME};
  do
    echo "Upgrade postgis in $db"
    case ${POSTGISVERSIONNEW} in
      3)
        cat << EOF | su postgres -c "psql -d $db"
        ALTER EXTENSION postgis UPDATE;
        -- this next step repackages raster in its own extension
        -- and upgrades all your other related postgis extensions
        SELECT postgis_extensions_upgrade();
EOF
        ;;

      2.5)
        cat << EOF | su postgres -c "psql -d $db"
        ALTER EXTENSION postgis UPDATE;
        -- this next step repackages raster in its own extension
        -- and upgrades all your other related postgis extensions
        ALTER EXTENSION postgis_sfcgal UPDATE;
        ALTER EXTENSION postgis_topology UPDATE;
        ALTER EXTENSION postgis_tiger_geocoder UPDATE;
EOF
        ;;
    esac
  done
fi

if [[ -f "/upgrade.d/post.sh" ]]; then
  echo "Post upgrade script exists. Executing post upgrade..."
  source /upgrade.d/post.sh
fi

echo "Upgrade finished."
echo "New cluster is in the location: ${PGDATANEW}"

pg_lsclusters
