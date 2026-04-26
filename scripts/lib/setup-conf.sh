#!/usr/bin/env bash


create_dir "${EXTRA_CONF_DIR}"
create_dir "${CONF_LOCKFILE_DIR}"
create_dir "${SCRIPTS_LOCKFILE_DIR}"

SETUP_LOCKFILE="${CONF_LOCKFILE_DIR}/.postgresql.conf.lock"

if [ -f "${SETUP_LOCKFILE}" ]; then
	return 0
fi

# Refresh configuration in case environment settings changed.
cat "${CONF}".template > "${CONF}"

# Reflect DATA DIR location
# Delete any data_dir declarations
sed -i '/data_directory/d' "${CONF}"

# Create a config to optimise postgis
postgis_configuration
logging_postgis_configuration
# Create a config for logical replication
logical_replication_configuration
# Create a config for streaming replication
streaming_replication_configuration
extra_conf_configuration
timescale_configuration

kernel_configuration

# Put lock file to make sure conf was not reinitialized
touch "${SETUP_LOCKFILE}"
