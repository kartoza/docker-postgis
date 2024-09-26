#!/bin/bash

# Log the current user
echo "Running as user: $(whoami)"

# Attempt to create the cron job
echo "0 2 * * * /usr/local/bin/pgbackrest-backup.sh >> /var/log/backup.log 2>&1" > /etc/cron.d/pgbackrest-cron

# Log the result
if [ $? -eq 0 ]; then
  echo "Successfully created cron job"
else
  echo "Failed to create cron job"
fi

# Set permissions
chmod 0644 /etc/cron.d/pgbackrest-cron

# Install the cron job
crontab /etc/cron.d/pgbackrest-cron

# Start the cron service
service cron start

# Keep the container running
tail -f /dev/null
