#!/usr/bin/env bash

# Display test environment variable

cat << EOF
Test environment:

Compose Project : ${COMPOSE_PROJECT_NAME}
Compose File    : ${COMPOSE_PROJECT_FILE}
Image tag       : ${TAG}

EOF
determine_compose_version(){
  if [[ $(dpkg -l | grep "docker-compose") > /dev/null ]];then
    export VERSION='docker-compose'
  else
    export VERSION='docker compose'
fi
}


wait_for_postgres() {
    local service=$1
    local compose_file="${2:-}"
    local max_attempts=30
    local attempt=0

    echo "Waiting for $service to be ready..."

    if [[ -n ${compose_file} ]];then
      extra_args="-f ${compose_file}"
    else
      extra_args=
    fi

    while [ $attempt -lt $max_attempts ]; do
        # Check if the ready marker file exists
        if ${VERSION} ${extra_args} exec -T $service test -f /tmp/postgres-ready 2>/dev/null; then
            echo "$service is ready!"
            return 0
        fi
        sleep 2
        ((attempt++))
    done

    echo "Timeout waiting for $service to be ready"
    return 1
}

wait_for_container_status() {
    local service=$1
    local max_attempts=30
    local attempt=0

    while [ $attempt -lt $max_attempts ]; do
        local status=$(${VERSION} ps $service --format json | jq -r '.State')
        if [[ "$status" == "exited" ]] || [[ "$status" == "dead" ]]; then
            return 0
        fi
        sleep 2
        ((attempt++))
    done
    return 1
}

# Function to wait for a log message in container logs
wait_for_log_message() {
    local service=$1
    local pattern=$2
    local compose_file=$3
    local max_attempts=30
    local attempt=0

    echo "Waiting for log message in $service: $pattern"

    while [ $attempt -lt $max_attempts ]; do
        if ${VERSION} -f "$compose_file" logs $service 2>&1 | grep -q "$pattern"; then
            echo "Found expected log message!"
            return 0
        fi
        sleep 2
        ((attempt++))
    done

    echo "Timeout waiting for log message in $service"
    return 1
}

run_tests(){
  local service=$1
  local compose_file="${2:-}"
  if [[ -n ${compose_file} ]];then
    extra_args="-f ${compose_file}"
  else
    extra_args=
  fi
  ${VERSION} ${extra_args}  exec -T $service /bin/bash /tests/test.sh
}