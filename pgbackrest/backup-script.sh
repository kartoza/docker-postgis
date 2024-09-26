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

# Create directories as root
create_pgbackrest_dirs "$LOG_DIR"
create_pgbackrest_dirs "$TMP_DIR"
create_pgbackrest_dirs "$BACKUP_DIR"

# Switch to postgres user to create pgBackRest stanza and run backup
su - postgres -c "pgbackrest --stanza=postgres stanza-create"
su - postgres -c "pgbackrest --stanza=postgres backup"
