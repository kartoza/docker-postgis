#!/bin/bash

# Set environment variables
export PGPASSWORD=${POSTGRES_PASS}
BACKUP_DIR="/var/lib/pgbackrest"
LOG_DIR="/var/log/pgbackrest"
TMP_DIR="/tmp/pgbackrest"

# Function to create directories and set permissions
create_pgbackrest_dirs() {
    local dir_path="$1"

    # Create the directory if it doesn't exist
    if [ ! -d "$dir_path" ]; then
        mkdir -p "$dir_path"
    fi

    # Change ownership to postgres user and set permissions
    chown -R postgres:postgres "$dir_path"
    chmod 700 "$dir_path"
}

# Switch to postgres user to create directories and permissions
su - postgres -c "
    create_pgbackrest_dirs '$LOG_DIR'
    create_pgbackrest_dirs '$TMP_DIR'
    create_pgbackrest_dirs '$BACKUP_DIR'
"

# Create a pgBackRest stanza as postgres user
su - postgres -c "pgbackrest --stanza=postgres stanza-create"

# Run pgBackRest backup as postgres user
su - postgres -c "pgbackrest --stanza=postgres backup"
