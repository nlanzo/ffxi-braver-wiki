#!/bin/bash
# Script to run MediaWiki update.php on Google Cloud Run
# This script creates a Cloud Run Job to execute update.php

set -e

# Configuration - Update these values
PROJECT_ID="${GCP_PROJECT_ID:-your-project-id}"
SERVICE_NAME="${SERVICE_NAME:-ffxi-braver-wiki}"
REGION="${REGION:-us-central1}"
IMAGE_NAME="${IMAGE_NAME:-us-central1-docker.pkg.dev/${PROJECT_ID}/ffxi-braver-wiki/ffxi-braver-wiki}"
JOB_NAME="${JOB_NAME:-mediawiki-update}"

# Get Cloud SQL connection name from secrets or environment
CLOUD_SQL_CONNECTION_NAME="${CLOUD_SQL_CONNECTION_NAME:-}"

if [ -z "$CLOUD_SQL_CONNECTION_NAME" ]; then
    echo "Error: CLOUD_SQL_CONNECTION_NAME must be set"
    echo "Usage: CLOUD_SQL_CONNECTION_NAME=project:region:instance ./run-update.php.sh"
    exit 1
fi

echo "Creating Cloud Run Job: $JOB_NAME"
echo "Using image: $IMAGE_NAME:latest"
echo "Cloud SQL connection: $CLOUD_SQL_CONNECTION_NAME"

# Create Cloud Run Job
gcloud run jobs create $JOB_NAME \
    --image=$IMAGE_NAME:latest \
    --region=$REGION \
    --set-env-vars="DB_TYPE=mysql,DB_NAME=${DB_NAME:-mediawiki},DB_USER=${DB_USER:-mediawiki},DB_PASSWORD=${DB_PASSWORD},CLOUD_SQL_CONNECTION_NAME=$CLOUD_SQL_CONNECTION_NAME,GCS_BUCKET_NAME=${GCS_BUCKET_NAME},GCS_ACCESS_KEY=${GCS_ACCESS_KEY},GCS_SECRET_KEY=${GCS_SECRET_KEY},WIKI_SITENAME=${WIKI_SITENAME},WIKI_SERVER=${WIKI_SERVER},WIKI_SECRET_KEY=${WIKI_SECRET_KEY},WIKI_UPGRADE_KEY=${WIKI_UPGRADE_KEY},SMTP_HOST=${SMTP_HOST},SMTP_PORT=${SMTP_PORT},SMTP_USERNAME=${SMTP_USERNAME},SMTP_PASSWORD=${SMTP_PASSWORD},WIKI_EMERGENCY_CONTACT=${WIKI_EMERGENCY_CONTACT},WIKI_PASSWORD_SENDER=${WIKI_PASSWORD_SENDER},WIKI_LOGO_URL=${WIKI_LOGO_URL},WIKI_FAVICON_URL=${WIKI_FAVICON_URL}" \
    --add-cloudsql-instances=$CLOUD_SQL_CONNECTION_NAME \
    --service-account=${GCP_SERVICE_ACCOUNT} \
    --memory=2Gi \
    --cpu=2 \
    --timeout=600 \
    --max-retries=1 \
    --command="/bin/sh" \
    --args="-c,php /var/www/html/maintenance/update.php --quick" \
    --wait || {
    echo "Job may already exist. Updating instead..."
    gcloud run jobs update $JOB_NAME \
        --image=$IMAGE_NAME:latest \
        --region=$REGION \
        --set-env-vars="DB_TYPE=mysql,DB_NAME=${DB_NAME:-mediawiki},DB_USER=${DB_USER:-mediawiki},DB_PASSWORD=${DB_PASSWORD},CLOUD_SQL_CONNECTION_NAME=$CLOUD_SQL_CONNECTION_NAME,GCS_BUCKET_NAME=${GCS_BUCKET_NAME},GCS_ACCESS_KEY=${GCS_ACCESS_KEY},GCS_SECRET_KEY=${GCS_SECRET_KEY},WIKI_SITENAME=${WIKI_SITENAME},WIKI_SERVER=${WIKI_SERVER},WIKI_SECRET_KEY=${WIKI_SECRET_KEY},WIKI_UPGRADE_KEY=${WIKI_UPGRADE_KEY},SMTP_HOST=${SMTP_HOST},SMTP_PORT=${SMTP_PORT},SMTP_USERNAME=${SMTP_USERNAME},SMTP_PASSWORD=${SMTP_PASSWORD},WIKI_EMERGENCY_CONTACT=${WIKI_EMERGENCY_CONTACT},WIKI_PASSWORD_SENDER=${WIKI_PASSWORD_SENDER},WIKI_LOGO_URL=${WIKI_LOGO_URL},WIKI_FAVICON_URL=${WIKI_FAVICON_URL}" \
        --add-cloudsql-instances=$CLOUD_SQL_CONNECTION_NAME \
        --service-account=${GCP_SERVICE_ACCOUNT} \
        --memory=2Gi \
        --cpu=2 \
        --timeout=600 \
        --max-retries=1 \
        --command="/bin/sh" \
        --args="-c,php /var/www/html/maintenance/update.php --quick"
}

echo ""
echo "Executing Cloud Run Job..."
gcloud run jobs execute $JOB_NAME --region=$REGION --wait

echo ""
echo "Job completed! View logs with:"
echo "gcloud run jobs executions logs read --job=$JOB_NAME --region=$REGION --limit=50"

