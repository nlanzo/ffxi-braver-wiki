# FFXI Braver Wiki - MediaWiki on Google Cloud Run

This repository contains a MediaWiki installation configured to run on Google Cloud Run with Cloud SQL and Cloud Storage.

## Quick Start

1. **Set up GCP resources** - Follow [DEPLOYMENT.md](./DEPLOYMENT.md) for detailed instructions
2. **Configure GitHub Secrets** - Add all required secrets to your GitHub repository
3. **Deploy** - Push to `main` branch to trigger automatic deployment

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

## Deployment

See [DEPLOYMENT.md](./DEPLOYMENT.md) for complete deployment instructions.

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
