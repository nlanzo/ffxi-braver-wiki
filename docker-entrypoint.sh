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

# Set proper permissions
chown -R www-data:www-data /var/www/html/images || true
chmod -R 755 /var/www/html/images || true

# Ensure LocalSettings.php exists (will be created by installer if not present)
if [ ! -f /var/www/html/LocalSettings.php ]; then
    echo "LocalSettings.php not found. MediaWiki installer will create it on first run."
fi

# Execute the main command
exec "$@"

