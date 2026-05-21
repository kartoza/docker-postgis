#!/usr/bin/env bash
#############################################
# Bootstrap
#############################################
# Import env and functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/env-data.sh"

#########################################
# Start Configuration
########################################
# Add any additional setup tasks here
chmod 600 /etc/ssl/private/ssl-cert-snakeoil.key

# Create backup template for conf
cat "${CONF}" > "${CONF}".template

# Create backup template for pg_hba.conf
sed -i 's/scram-sha-256/${PASSWORD_AUTHENTICATION}/g' "${ROOT_CONF}"/pg_hba.conf


cat "${ROOT_CONF}"/pg_hba.conf > "${ROOT_CONF}"/pg_hba.conf.template


