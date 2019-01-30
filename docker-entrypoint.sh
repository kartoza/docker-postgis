#!/usr/bin/env bash

# This script will run as the postgres user due to the Dockerfile USER directive
set -e

# Setup postgres CONF file
if grep -rlq "#user-settings" /etc/postgresql/9.6/main/postgresql.conf
then
    echo "postgres conf already configured"
else
    source /setup-conf.sh
fi


# Setup ssl

# Setup ssl
if grep -rlq "ssl-cert-snakeoil.pem" /etc/postgresql/9.6/main/postgresql.conf
then
    echo "ssl already configured"
else
    echo "SSL not configures so proceed to setup"
    source /setup-ssl.sh

fi

# Setup pg_hba.conf
if grep -rlq "172.0.0.0/8" /etc/postgresql/9.6/main/pg_hba.conf
then
    echo "pg_hba  already configured"
else
    echo "we will setup pg_hba conf"
    source /setup-pg_hba.sh
fi

if [[ -z "$REPLICATE_FROM" ]]; then
	# This means this is a master instance. We check that database exists
	echo "Setup master database"
	source /setup-database.sh
else
	# This means this is a slave/replication instance.
	echo "Setup slave database"
	source /setup-replication.sh
fi

# Running extended script or sql if provided.
# Useful for people who extends the image.

echo
for f in /docker-entrypoint-initdb.d/*; do
	case "$f" in
		*.sh)     echo "$0: running $f"; . "$f" ;;
		*.sql)    echo "$0: running $f"; "${psql[@]}" < "$f"; echo ;;
		*.sql.gz) echo "$0: running $f"; gunzip -c "$f" | "${psql[@]}"; echo ;;
		*)        echo "$0: ignoring $f" ;;
	esac
	echo
done

# If no arguments passed to entrypoint, then run postgres by default
if [[ $# -eq 0 ]];
then
	echo "Postgres initialisation process completed .... restarting in foreground"

	su - postgres -c "$SETVARS $POSTGRES -D $DATADIR -c config_file=$CONF"
fi

# If arguments passed, run postgres with these arguments
# This will make sure entrypoint will always be executed
if [[ "${1:0:1}" = '-' ]]; then
	# append postgres into the arguments
	set -- postgres "$@"
fi

exec su - "$@"
