#!/bin/bash

# Set up conditional flags based on environment variables
SKIP_EXPIRY_CHECK=""
if [ "$DEBUG" = "true" ]; then
  SKIP_EXPIRY_CHECK="--skip-expiry-check"
fi

NO_REBOOT_FLAG=""
if [ "$NO_REBOOT" = "true" ]; then
  NO_REBOOT_FLAG="--no-reboot"
fi

DEBUG_FLAG=""
if [ "$DEBUG" = "true" ]; then
  DEBUG_FLAG="--debug"
fi

# Find the path of the poetry executable
POETRY_PATH=$(which poetry)

# Set up the cron job with the dynamic CRON_STRING
echo "$CRON_STRING cd /app && $POETRY_PATH run python /app/main.py --ipmi-url \$IPMI_URL --key-file \$KEY_FILE --cert-file \$CERT_FILE --username \$USERNAME --password \$PASSWORD $SKIP_EXPIRY_CHECK $NO_REBOOT_FLAG $DEBUG_FLAG >> /proc/1/fd/1 2>> /proc/1/fd/2" | crontab -

# Ensure environment variables are available for cron jobs
printenv | grep -v "no_proxy" >> /etc/environment

# Start the cron daemon in the foreground
cron -f