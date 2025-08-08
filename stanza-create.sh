#!/bin/bash

# Wait for PostgreSQL to be ready
until pg_isready -h localhost -U "$POSTGRES_USER" -d "$POSTGRES_DB"; do
  echo "Waiting for PostgreSQL..."
  sleep 2
done

# Create the stanza if it doesn't exist
if ! pgbackrest info --stanza=postgres > /dev/null 2>&1; then
  echo "Creating pgBackRest stanza..."
  pgbackrest --stanza=postgres stanza-create
else
  echo "Stanza already exists."
fi
