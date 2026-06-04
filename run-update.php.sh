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
    --set-cloudsql-instances=$CLOUD_SQL_CONNECTION_NAME \
    --service-account=${GCP_SERVICE_ACCOUNT} \
    --memory=1Gi \
    --cpu=1 \
    --task-timeout=600 \
    --max-retries=1 \
    --command="/bin/sh" \
    --args="-c,set -e; cd /var/www/html; if [ ! -f LocalSettings.php ]; then cp LocalSettings.php.template LocalSettings.php; fi; /usr/local/bin/php maintenance/update.php --quick" \
    --wait || {
    echo "Job may already exist. Updating instead..."
    gcloud run jobs update $JOB_NAME \
        --image=$IMAGE_NAME:latest \
        --region=$REGION \
        --set-env-vars="DB_TYPE=mysql,DB_NAME=${DB_NAME:-mediawiki},DB_USER=${DB_USER:-mediawiki},DB_PASSWORD=${DB_PASSWORD},CLOUD_SQL_CONNECTION_NAME=$CLOUD_SQL_CONNECTION_NAME,GCS_BUCKET_NAME=${GCS_BUCKET_NAME},GCS_ACCESS_KEY=${GCS_ACCESS_KEY},GCS_SECRET_KEY=${GCS_SECRET_KEY},WIKI_SITENAME=${WIKI_SITENAME},WIKI_SERVER=${WIKI_SERVER},WIKI_SECRET_KEY=${WIKI_SECRET_KEY},WIKI_UPGRADE_KEY=${WIKI_UPGRADE_KEY},SMTP_HOST=${SMTP_HOST},SMTP_PORT=${SMTP_PORT},SMTP_USERNAME=${SMTP_USERNAME},SMTP_PASSWORD=${SMTP_PASSWORD},WIKI_EMERGENCY_CONTACT=${WIKI_EMERGENCY_CONTACT},WIKI_PASSWORD_SENDER=${WIKI_PASSWORD_SENDER},WIKI_LOGO_URL=${WIKI_LOGO_URL},WIKI_FAVICON_URL=${WIKI_FAVICON_URL}" \
        --set-cloudsql-instances=$CLOUD_SQL_CONNECTION_NAME \
        --service-account=${GCP_SERVICE_ACCOUNT} \
        --memory=1Gi \
        --cpu=1 \
        --task-timeout=600 \
        --max-retries=1 \
        --command="/bin/sh" \
        --args="-c,set -e; cd /var/www/html; if [ ! -f LocalSettings.php ]; then cp LocalSettings.php.template LocalSettings.php; fi; /usr/local/bin/php maintenance/update.php --quick"
}

echo ""
echo "Executing Cloud Run Job..."
EXECUTION_OUTPUT=$(gcloud run jobs execute $JOB_NAME --region=$REGION --wait 2>&1)
EXIT_CODE=$?

# Extract execution name from output if available
EXECUTION_NAME=$(echo "$EXECUTION_OUTPUT" | grep -oP 'executions/\K[^\s]+' | head -1 || echo "")

echo ""
if [ $EXIT_CODE -eq 0 ]; then
    echo "✓ Job completed successfully!"
else
    echo "✗ Job failed with exit code $EXIT_CODE"
fi

echo ""
echo "Fetching logs from the most recent execution..."
# Get the latest execution name
LATEST_EXEC=$(gcloud run jobs executions list --job=$JOB_NAME --region=$REGION --limit=1 --format="value(name)" 2>/dev/null | head -1)

if [ -n "$LATEST_EXEC" ]; then
    echo "Latest execution: $LATEST_EXEC"
    echo ""
    echo "=== Execution Details ==="
    gcloud run jobs executions describe "$LATEST_EXEC" --region=$REGION 2>/dev/null || true
    echo ""
    echo "=== Execution Logs ==="
    # Use Cloud Logging to get logs for the execution
    EXEC_ID=$(echo "$LATEST_EXEC" | awk -F'/' '{print $NF}')
    gcloud logging read "resource.type=cloud_run_job AND resource.labels.job_name=$JOB_NAME AND resource.labels.location=$REGION AND resource.labels.execution_name=$EXEC_ID" \
        --limit=200 \
        --format="table(timestamp,textPayload)" \
        --project=$PROJECT_ID 2>/dev/null || \
    gcloud logging read "resource.type=cloud_run_job AND resource.labels.job_name=$JOB_NAME AND resource.labels.location=$REGION" \
        --limit=200 \
        --format="table(timestamp,textPayload)" \
        --project=$PROJECT_ID 2>/dev/null || \
    echo "Note: Logs may take a few moments to appear. View them in Cloud Console:"
    echo "https://console.cloud.google.com/run/jobs/executions/details/$REGION/$EXEC_ID?project=$PROJECT_ID"
else
    echo "Could not find execution. View logs in Cloud Console:"
    echo "https://console.cloud.google.com/run/jobs/details/$REGION/$JOB_NAME?project=$PROJECT_ID"
fi

if [ $EXIT_CODE -ne 0 ]; then
    echo ""
    echo "To view detailed execution information, run:"
    LATEST_EXEC=$(gcloud run jobs executions list --job=$JOB_NAME --region=$REGION --limit=1 --format="value(name)" 2>/dev/null | head -1)
    if [ -n "$LATEST_EXEC" ]; then
        EXEC_ID=$(echo "$LATEST_EXEC" | awk -F'/' '{print $NF}')
        echo "gcloud run jobs executions describe $LATEST_EXEC --region=$REGION"
        echo ""
        echo "Or view in Cloud Console:"
        echo "https://console.cloud.google.com/run/jobs/executions/details/$REGION/$EXEC_ID?project=$PROJECT_ID"
    else
        echo "gcloud run jobs executions list --job=$JOB_NAME --region=$REGION --limit=1"
        echo "Then: gcloud run jobs executions describe <EXECUTION_NAME> --region=$REGION"
    fi
    exit $EXIT_CODE
fi

