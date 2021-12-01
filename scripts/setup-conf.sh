#!/usr/bin/env bash

source /scripts/env-data.sh

SETUP_LOCKFILE="${ROOT_CONF}/.postgresql.conf.lock"
create_dir /settings
if [ -f "${SETUP_LOCKFILE}" ]; then
	return 0
fi

# Refresh configuration in case environment settings changed.
cat $CONF.template > $CONF

# Reflect DATA DIR location
# Delete any data_dir declarations
sed -i '/data_directory/d' $CONF

# Create a config to optimise postgis
cat > ${ROOT_CONF}/postgis.conf <<EOF
data_directory = '${DATADIR}'
port = 5432
superuser_reserved_connections= 10
listen_addresses = '${IP_LIST}'
shared_buffers = ${SHARED_BUFFERS}
work_mem = ${WORK_MEM}
maintenance_work_mem = ${MAINTAINANCE_WORK_MEM}
wal_buffers = ${WAL_BUFFERS}
random_page_cost = 2.0
xmloption = 'document'
max_parallel_maintenance_workers = ${MAINTAINANCE_WORKERS}
max_parallel_workers = ${MAX_WORKERS}
shared_preload_libraries = '${SHARED_PRELOAD_LIBRARIES}'
cron.database_name = '${SINGLE_DB}'
password_encryption= '${PASSWORD_AUTHENTICATION}'
timezone='${TIMEZONE}'
cron.use_background_workers = on
EOF

echo "include 'postgis.conf'" >> $CONF

# Create a config for logical replication
if [[  "${REPLICATION}" =~ [Tt][Rr][Uu][Ee] && "$WAL_LEVEL" == 'logical' ]]; then

cat > ${ROOT_CONF}/logical_replication.conf <<EOF
wal_level = ${WAL_LEVEL}
max_wal_senders = ${PG_MAX_WAL_SENDERS}
wal_keep_size = ${PG_WAL_KEEP_SIZE}
min_wal_size = ${MIN_WAL_SIZE}
max_wal_size = ${WAL_SIZE}
max_logical_replication_workers = ${MAX_LOGICAL_REPLICATION_WORKERS}
max_sync_workers_per_subscription = ${MAX_SYNC_WORKERS_PER_SUBSCRIPTION}
EOF
echo "include 'logical_replication.conf'" >> $CONF
fi

# Create a config for streaming replication
if [[ "${REPLICATION}" =~ [Tt][Rr][Uu][Ee] &&  "$WAL_LEVEL" == 'replica' ]]; then

cat > ${ROOT_CONF}/streaming_replication.conf <<EOF
wal_level = ${WAL_LEVEL}
archive_mode = ${ARCHIVE_MODE}
archive_command = '${ARCHIVE_COMMAND}'
restore_command = '${RESTORE_COMMAND}'
archive_cleanup_command = '${ARCHIVE_CLEANUP_COMMAND}'
max_wal_senders = ${PG_MAX_WAL_SENDERS}
wal_keep_size = ${PG_WAL_KEEP_SIZE}
min_wal_size = ${MIN_WAL_SIZE}
max_wal_size = ${WAL_SIZE}
hot_standby = on
checkpoint_timeout = ${CHECK_POINT_TIMEOUT}
primary_conninfo = 'host=${REPLICATE_FROM} port=${REPLICATE_PORT} user=${REPLICATION_USER} password=${REPLICATION_PASS} sslmode=${PGSSLMODE}'
recovery_target_timeline=${TARGET_TIMELINE}
recovery_target_action=${TARGET_ACTION}
promote_trigger_file = '${PROMOTE_FILE}'
EOF
echo "include 'streaming_replication.conf'" >> $CONF
fi

if [[ ! -f ${ROOT_CONF}/extra.conf ]]; then
    # If it doesn't exists, copy from /settings directory if exists
    if [[ -f /settings/extra.conf ]]; then
      cp -f /settings/extra.conf ${ROOT_CONF}/extra.conf
      echo "include 'extra.conf'" >> $CONF
    else
      # default value
      if [[  -n "$EXTRA_CONF" ]]; then
          echo -e $EXTRA_CONF >> ${ROOT_CONF}/extra.conf
          echo "include 'extra.conf'" >> $CONF
      fi
    fi

fi

# Timescale default tuning
# TODO If timescale DB accepts reading from include directory then refactor code to remove line 97 - 112 (https://github.com/timescale/timescaledb-tune/issues/80)
if [[ ${ACCEPT_TIMESCALE_TUNING} =~ [Tt][Rr][Uu][Ee] ]];then
  if [[ -f ${ROOT_CONF}/postgis.conf ]];then
    sed -i '/postgis.conf/d' "${ROOT_CONF}"/postgresql.conf
    cat "${ROOT_CONF}"/postgis.conf >> "${ROOT_CONF}"/postgresql.conf
  fi
  if [[ -f ${ROOT_CONF}/logical_replication.conf ]];then
    sed -i '/logical_replication.conf/d' "${ROOT_CONF}"/postgresql.conf
    cat "${ROOT_CONF}"/logical_replication.conf >> "${ROOT_CONF}"/postgresql.conf
  fi
  if [[ -f ${ROOT_CONF}/streaming_replication.conf ]];then
    sed -i '/streaming_replication.conf/d' "${ROOT_CONF}"/postgresql.conf
    cat "${ROOT_CONF}"/streaming_replication.conf >> "${ROOT_CONF}"/postgresql.conf
  fi
  if [[ -f ${ROOT_CONF}/extra.conf ]];then
    sed -i '/extra.conf/d' "${ROOT_CONF}"/postgresql.conf
    cat "${ROOT_CONF}"/extra.conf >> "${ROOT_CONF}"/postgresql.conf
  fi
  echo -e "\e[1;31m Time scale config tuning values below"
  # TODO Add logic to find defaults memory, CPUS as these can vary from defaults on host machine and in docker container
  timescaledb-tune  -yes -quiet "${TIMESCALE_TUNING_PARAMS}" --conf-path="${ROOT_CONF}"/postgresql.conf
  echo -e "\033[0m Time scale config tuning values set in ${ROOT_CONF}/postgresql.conf"
fi

# Optimise PostgreSQL shared memory for PostGIS
# shmall units are pages and shmmax units are bytes(?) equivalent to the desired shared_buffer size set in setup_conf.sh - in this case 500MB
echo "kernel.shmmax=543252480" >> /etc/sysctl.conf
echo "kernel.shmall=2097152" >> /etc/sysctl.conf

# Put lock file to make sure conf was not reinitialized
touch ${SETUP_LOCKFILE}
