# Multi-stage build for MediaWiki on Cloud Run
FROM php:8.2-fpm-alpine AS builder

# Install build dependencies
RUN apk add --no-cache \
    git \
    unzip \
    curl \
    libpng-dev \
    libjpeg-turbo-dev \
    freetype-dev \
    libzip-dev \
    icu-dev \
    oniguruma-dev \
    postgresql-dev \
    && docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install -j$(nproc) \
    calendar \
    gd \
    mysqli \
    pdo \
    pdo_mysql \
    pdo_pgsql \
    zip \
    intl \
    mbstring \
    opcache \
    bcmath

# Install Composer
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

# Set working directory
WORKDIR /var/www/html

# Copy MediaWiki files
COPY mediawiki-1.44.2/ /var/www/html/

# Note: ExternalStorage extension should be installed manually after deployment
# Cloud Storage integration can be configured via MediaWiki extensions
# See documentation for installing ExternalStorage or other GCS-compatible extensions

# Install PHP dependencies if composer.json exists
RUN if [ -f composer.json ]; then \
    composer install --no-dev --optimize-autoloader --no-interaction; \
    fi

# Production stage
FROM php:8.2-fpm-alpine

# Create wait script for PHP-FPM
RUN echo '#!/bin/sh' > /wait-for-php-fpm.sh \
    && echo 'set -e' >> /wait-for-php-fpm.sh \
    && echo 'echo "Waiting for PHP-FPM to be ready..."' >> /wait-for-php-fpm.sh \
    && echo 'for i in $(seq 1 30); do' >> /wait-for-php-fpm.sh \
    && echo '  if nc -z 127.0.0.1 9000 2>/dev/null; then' >> /wait-for-php-fpm.sh \
    && echo '    echo "PHP-FPM is ready!"' >> /wait-for-php-fpm.sh \
    && echo '    exit 0' >> /wait-for-php-fpm.sh \
    && echo '  fi' >> /wait-for-php-fpm.sh \
    && echo '  sleep 0.1' >> /wait-for-php-fpm.sh \
    && echo 'done' >> /wait-for-php-fpm.sh \
    && echo 'echo "Warning: PHP-FPM did not become ready in time"' >> /wait-for-php-fpm.sh \
    && echo 'exit 0' >> /wait-for-php-fpm.sh \
    && chmod +x /wait-for-php-fpm.sh

# Install runtime dependencies and build dependencies for PHP extensions
RUN apk add --no-cache \
    nginx \
    supervisor \
    netcat-openbsd \
    libpng \
    libjpeg-turbo \
    freetype \
    libzip \
    icu \
    oniguruma \
    postgresql-libs \
    mysql-client \
    netcat-openbsd \
    && apk add --no-cache --virtual .build-deps \
    zlib-dev \
    libpng-dev \
    libjpeg-turbo-dev \
    freetype-dev \
    libzip-dev \
    icu-dev \
    oniguruma-dev \
    postgresql-dev \
    && docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install -j$(nproc) \
    calendar \
    gd \
    mysqli \
    pdo \
    pdo_mysql \
    pdo_pgsql \
    zip \
    intl \
    mbstring \
    opcache \
    bcmath \
    && apk del .build-deps \
    && rm -rf /var/cache/apk/*

# Install Cloud SQL Proxy for Cloud SQL connections
RUN wget -q https://storage.googleapis.com/cloud-sql-connectors/cloud-sql-proxy/v2.8.0/cloud-sql-proxy.linux.amd64 \
    -O /usr/local/bin/cloud-sql-proxy \
    && chmod +x /usr/local/bin/cloud-sql-proxy

# Note: Cloud Storage integration is handled via MediaWiki extensions using Cloud Storage API
# Cloud Run doesn't support FUSE, so gcsfuse is not used
# Install MediaWiki extensions like ExternalStorage with GCS backend for Cloud Storage integration

# Configure PHP for Cloud Run
RUN { \
    echo 'memory_limit = 256M'; \
    echo 'upload_max_filesize = 20M'; \
    echo 'post_max_size = 20M'; \
    echo 'max_execution_time = 300'; \
    echo 'max_input_time = 300'; \
    echo 'date.timezone = UTC'; \
    } > /usr/local/etc/php/conf.d/mediawiki.ini

# Configure PHP-FPM for Cloud Run
# Remove default www.conf to avoid conflicts
RUN rm -f /usr/local/etc/php-fpm.d/www.conf.default /usr/local/etc/php-fpm.d/zz-docker.conf 2>/dev/null || true \
    && { \
    echo '[global]'; \
    echo 'daemonize = no'; \
    echo 'error_log = /proc/self/fd/2'; \
    echo '[www]'; \
    echo 'listen = 127.0.0.1:9000'; \
    echo 'listen.owner = www-data'; \
    echo 'listen.group = www-data'; \
    echo 'user = www-data'; \
    echo 'group = www-data'; \
    echo 'pm = dynamic'; \
    echo 'pm.max_children = 10'; \
    echo 'pm.start_servers = 2'; \
    echo 'pm.min_spare_servers = 1'; \
    echo 'pm.max_spare_servers = 3'; \
    echo 'catch_workers_output = yes'; \
    echo 'php_admin_value[error_log] = /proc/self/fd/2'; \
    echo 'php_admin_flag[log_errors] = on'; \
    } > /usr/local/etc/php-fpm.d/mediawiki.conf

# Configure Nginx
RUN { \
    echo 'user www-data;'; \
    echo 'worker_processes auto;'; \
    echo 'error_log /proc/self/fd/2 warn;'; \
    echo 'pid /var/run/nginx.pid;'; \
    echo 'events { worker_connections 1024; }'; \
    echo 'http {'; \
    echo '  include /etc/nginx/mime.types;'; \
    echo '  default_type application/octet-stream;'; \
    echo '  log_format main '"'"'$remote_addr - $remote_user [$time_local] "$request" '"'"' '"'"'$status $body_bytes_sent "$http_referer" '"'"' '"'"'"$http_user_agent" "$http_x_forwarded_for"'"'"';'; \
    echo '  access_log /proc/self/fd/1 main;'; \
    echo '  sendfile on;'; \
    echo '  keepalive_timeout 65;'; \
    echo '  client_max_body_size 20M;'; \
    echo '  server {'; \
    echo '    listen 8080;'; \
    echo '    server_name _;'; \
    echo '    root /var/www/html;'; \
    echo '    index index.php;'; \
    echo '    # Security: Prevent PHP execution in uploads directory'; \
    echo '    location ~ ^/images/.*\.php$ { deny all; }'; \
    echo '    # Security headers for uploads directory'; \
    echo '    location /images/ {'; \
    echo '      add_header X-Content-Type-Options "nosniff" always;'; \
    echo '    }'; \
    echo '    location / {'; \
    echo '      try_files $uri $uri/ /index.php?$query_string;'; \
    echo '    }'; \
    echo '    location ~ \.php$ {'; \
    echo '      fastcgi_pass 127.0.0.1:9000;'; \
    echo '      fastcgi_index index.php;'; \
    echo '      fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;'; \
    echo '      include fastcgi_params;'; \
    echo '    }'; \
    echo '    location ~ /\. { deny all; }'; \
    echo '  }'; \
    echo '}'; \
    } > /etc/nginx/nginx.conf

# Configure Supervisor
RUN mkdir -p /etc/supervisor/conf.d \
    && { \
    echo '[supervisord]'; \
    echo 'nodaemon=true'; \
    echo 'user=root'; \
    echo '[program:php-fpm]'; \
    echo 'command=php-fpm'; \
    echo 'priority=10'; \
    echo 'autorestart=true'; \
    echo 'startretries=3'; \
    echo 'startsecs=2'; \
    echo 'stdout_logfile=/dev/stdout'; \
    echo 'stdout_logfile_maxbytes=0'; \
    echo 'stderr_logfile=/dev/stderr'; \
    echo 'stderr_logfile_maxbytes=0'; \
    echo '[program:nginx]'; \
    echo 'command=/bin/sh -c "/wait-for-php-fpm.sh && nginx -g \\\"daemon off;\\\""'; \
    echo 'priority=20'; \
    echo 'autorestart=true'; \
    echo 'startretries=3'; \
    echo 'startsecs=1'; \
    echo 'stdout_logfile=/dev/stdout'; \
    echo 'stdout_logfile_maxbytes=0'; \
    echo 'stderr_logfile=/dev/stderr'; \
    echo 'stderr_logfile_maxbytes=0'; \
    } > /etc/supervisor/conf.d/supervisord.conf

# Copy application files from builder
COPY --from=builder --chown=www-data:www-data /var/www/html /var/www/html

# Create necessary directories with proper permissions
RUN mkdir -p /var/www/html/images \
    && chown -R www-data:www-data /var/www/html \
    && chmod -R 755 /var/www/html

# Copy entrypoint script
COPY docker-entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

# Expose port 8080 (Cloud Run requirement)
EXPOSE 8080

# Use supervisor to manage nginx and php-fpm
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]

