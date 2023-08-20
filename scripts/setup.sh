#!/usr/bin/env bash
# Add any additional setup tasks here
chmod 600 /etc/ssl/private/ssl-cert-snakeoil.key

# These tasks are run as root
source /scripts/env-data.sh

# Create backup template for conf
cat "${CONF}" > "${CONF}".template

# Create backup template for pg_hba.conf
sed -i 's/scram-sha-256/${PASSWORD_AUTHENTICATION}/g' "${ROOT_CONF}"/pg_hba.conf
sed -i 's/md5/${PASSWORD_AUTHENTICATION}/g' "${ROOT_CONF}"/pg_hba.conf


cat "${ROOT_CONF}"/pg_hba.conf > "${ROOT_CONF}"/pg_hba.conf.template


