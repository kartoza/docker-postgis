#!/usr/bin/env bash

generate_random_string() {
  local length="$1"
  local file="/scripts/.pass_${length}.txt"

  [[ -f "${file}" ]] || tr -dc '[:alnum:]' </dev/urandom | head -c "${length}" > "${file}"
  RAND="$(<"${file}")"
  export RAND
}


create_dir() {
  local DATA_PATH="$1"

  if [[ -z "${DATA_PATH}" ]]; then
    echo -e "\e[31m [ERROR] create_dir: No path provided \033[0m" >&2
    return 1
  fi

  if [[ ! -d "${DATA_PATH}" ]]; then
    if ! mkdir -p "${DATA_PATH}"; then
      echo -e "\e[31m [ERROR] Failed to create directory: ${DATA_PATH} \033[0m" >&2
      return 1
    fi
  fi
}

directory_checker() {
  local DATA_PATH=$1
  if [ -d "$DATA_PATH" ]; then
    local DB_USER_PERM
    local DB_GRP_PERM
    DB_USER_PERM=$(stat -c '%U' "${DATA_PATH}")
    DB_GRP_PERM=$(stat -c '%G' "${DATA_PATH}")

    if [[ ${DB_USER_PERM} != "${USER}" ]] || [[ ${DB_GRP_PERM} != "${GROUP}" ]]; then
      chown -R "${USER}:${GROUP}" "${DATA_PATH}"
    fi
  else
    chown "${USER}:${GROUP}" "${DATA_PATH}"
  fi
}

############################################
# 2. RUNTIME USER & GROUP MANAGEMENT
############################################

init_runtime_user_vars() {
  USER_ID="${POSTGRES_UID:-1000}"
  GROUP_ID="${POSTGRES_GID:-1000}"
  USER_NAME="${USER:-postgresuser}"
  DB_GROUP_NAME="${GROUP_NAME:-postgresusers}"

  export USER_ID GROUP_ID USER_NAME DB_GROUP_NAME
}

ensure_group_exists() {
  if ! getent group "${DB_GROUP_NAME}" >/dev/null; then
    groupadd -r "${DB_GROUP_NAME}" -g "${GROUP_ID}"
  fi
}

ensure_user_exists() {
  if ! id -u "${USER_NAME}" >/dev/null 2>&1; then
    useradd \
      -l \
      -m \
      -d "/home/${USER_NAME}" \
      -u "${USER_ID}" \
      --gid "${GROUP_ID}" \
      -s /bin/bash \
      -G "${DB_GROUP_NAME}" \
      "${USER_NAME}"
  fi
}

setup_postgres_users() {
  init_runtime_user_vars
  ensure_group_exists
  ensure_user_exists
}

data_directory_ownership() {
  dir_ownership=("${DATADIR}" "${WAL_ARCHIVE}")
  for directory in "${dir_ownership[@]}"; do
    if [[ $(stat -c '%U' "${directory}") != "postgres" ]] && [[ $(stat -c '%G' "${directory}") != "postgres" ]];then
      chown -R postgres:postgres "${directory}"
    fi
  done
  for directory in "${dir_ownership[@]}"; do
    if [ "$(stat -c %a "$directory")" != "750" ]; then
        chmod -R 750 "$directory"
    fi
  done
}

start_postgres_marker(){
  if [[ -f /tmp/postgres-ready ]]; then
    rm -f /tmp/postgres-ready
  fi
}

entrypoint_figlet(){
  local START_TEXT="Kartoza Docker PostGIS"
  figlet -t ${START_TEXT}
}