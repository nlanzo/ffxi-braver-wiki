#!/bin/sh
set -e

# Create images directory for MediaWiki uploads
# Note: Cloud Storage integration is handled via MediaWiki extensions using Cloud Storage API
# Cloud Run doesn't support FUSE, so we use local storage or Cloud Storage API extensions
mkdir -p /var/www/html/images

# Cloud Run automatically provides Cloud SQL socket at /cloudsql/CONNECTION_NAME
# No need to start Cloud SQL Proxy manually when using --add-cloudsql-instances
if [ -n "$CLOUD_SQL_CONNECTION_NAME" ]; then
    SOCKET_PATH="/cloudsql/$CLOUD_SQL_CONNECTION_NAME"
    echo "Checking for Cloud SQL socket at $SOCKET_PATH..."
    if [ -d "/cloudsql" ]; then
        echo "Cloud SQL socket directory exists"
        # List available sockets
        ls -la /cloudsql/ || true
    fi
fi

# Set proper permissions for MediaWiki
# Images directory needs to be writable for uploads
chown -R www-data:www-data /var/www/html/images || true
chmod -R 775 /var/www/html/images || true

# Ensure cache directory exists and is writable
mkdir -p /var/www/html/cache || true
chown -R www-data:www-data /var/www/html/cache || true
chmod -R 775 /var/www/html/cache || true

# Copy LocalSettings.php template if it doesn't exist locally
# The template reads all sensitive values from environment variables (GitHub Secrets)
if [ ! -f /var/www/html/LocalSettings.php ]; then
    echo "LocalSettings.php not found. Using secure template (reads from environment variables)."
    cp /var/www/html/LocalSettings.php.template /var/www/html/LocalSettings.php
    chown www-data:www-data /var/www/html/LocalSettings.php
    chmod 644 /var/www/html/LocalSettings.php
fi

# Execute the main command
exec "$@"

