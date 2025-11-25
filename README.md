# FFXI Braver Wiki - MediaWiki on Google Cloud Run

This repository contains a MediaWiki installation configured to run on Google Cloud Run with Cloud SQL and Cloud Storage.

## Architecture

- **Compute**: Google Cloud Run (serverless containers)
- **Database**: Cloud SQL (MySQL)
- **Storage**: Cloud Storage (for file uploads)
- **CI/CD**: GitHub Actions
- **Container Registry**: Google Artifact Registry

## Features

- Serverless deployment on Cloud Run
- Cloud SQL integration (MySQL)
- Cloud Storage for file uploads (via gcsfuse)
- Automated CI/CD with GitHub Actions
- Scalable and cost-effective

## Requirements

- Google Cloud Platform account
- GitHub repository
- MediaWiki 1.44.2 source files

## Local Development

```bash
# Build Docker image
docker build -t mediawiki-local .

# Run locally
docker run -p 8080:8080 \
    -e DB_TYPE=mysql \
    -e DB_NAME=mediawiki \
    -e DB_USER=mediawiki \
    -e DB_PASSWORD=password \
    -e DB_HOST=host.docker.internal \
    mediawiki-local
```

## License

MediaWiki is licensed under GPL-2.0-or-later. See MediaWiki source for details.
