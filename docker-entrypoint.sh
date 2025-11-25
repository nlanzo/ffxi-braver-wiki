#!/bin/sh
set -e

# Mount GCS bucket if GCS_BUCKET_NAME is set
if [ -n "$GCS_BUCKET_NAME" ]; then
    echo "Mounting GCS bucket: $GCS_BUCKET_NAME"
    mkdir -p /var/www/html/images
    # Mount GCS bucket to images directory
    # Note: gcsfuse requires FUSE privileges, which Cloud Run may not provide
    # Alternative: Use Cloud Storage API directly or mount at container startup
    if command -v gcsfuse >/dev/null 2>&1; then
        gcsfuse --implicit-dirs --file-mode=0666 --dir-mode=0777 "$GCS_BUCKET_NAME" /var/www/html/images || {
            echo "Warning: Failed to mount GCS bucket. Continuing with local storage..."
            mkdir -p /var/www/html/images
        }
    else
        echo "gcsfuse not available, using local storage"
        mkdir -p /var/www/html/images
    fi
fi

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

