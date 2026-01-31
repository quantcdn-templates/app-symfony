FROM ghcr.io/quantcdn-templates/app-apache-php:8.4

# Remap www-data to UID/GID 1000 to match EFS access points
RUN groupmod -g 1000 www-data && \
    usermod -u 1000 -g 1000 www-data && \
    # Fix ownership of existing www-data files after UID/GID change
    find / -user 33 -exec chown www-data {} \; 2>/dev/null || true && \
    find / -group 33 -exec chgrp www-data {} \; 2>/dev/null || true && \
    # Configure Apache to run as root but serve files as www-data
    sed -i 's/ErrorLog .*/ErrorLog \/dev\/stderr/' /etc/apache2/apache2.conf && \
    sed -i 's/CustomLog .*/CustomLog \/dev\/stdout combined/' /etc/apache2/sites-available/000-default.conf && \
    # Set Apache to run as root to bind to port 80, but PHP files served as www-data
    sed -i 's/export APACHE_RUN_USER=.*/export APACHE_RUN_USER=root/' /etc/apache2/envvars && \
    sed -i 's/export APACHE_RUN_GROUP=.*/export APACHE_RUN_GROUP=root/' /etc/apache2/envvars && \
    # Ensure Apache run directory exists and has correct permissions
    mkdir -p /var/run/apache2 && \
    chown -R www-data:www-data /var/run/apache2

# Install additional system packages and configure Apache modules
# Base image already has most PHP extensions (gd, opcache, pdo_mysql, pdo_pgsql, zip, bcmath, intl, redis, apcu)
RUN set -eux; \
    # Enable Apache modules
    a2enmod rewrite headers proxy proxy_http remoteip 2>/dev/null || true; \
    \
    # Configure mod_remoteip for proper client IP handling
    echo 'RemoteIPHeader Quant-Client-IP' >> /etc/apache2/conf-available/remoteip.conf && \
    a2enconf remoteip 2>/dev/null || true; \
    \
    # Install additional packages if needed
    apt-get update && apt-get install -y --no-install-recommends \
        default-mysql-client \
        vim \
        git \
        jq \
        curl \
        sudo \
        gosu \
        unzip \
    && rm -rf /var/lib/apt/lists/*

# Set PHP configuration for Symfony
RUN { \
        echo 'opcache.memory_consumption=300'; \
        echo 'opcache.interned_strings_buffer=8'; \
        echo 'opcache.max_accelerated_files=30000'; \
        echo 'opcache.revalidate_freq=60'; \
    } > /usr/local/etc/php/conf.d/opcache-recommended.ini && \
    echo 'memory_limit = 256M' >> /usr/local/etc/php/conf.d/docker-php-memlimit.ini

# Install Composer
COPY --from=composer:2 /usr/bin/composer /usr/local/bin/

# Set working directory
WORKDIR /var/www/html

# Copy dependency files first (changes occasionally)
COPY src/composer.json src/composer.lock* ./

# Install PHP dependencies (cached until composer files change)
# If composer.lock doesn't exist or is incomplete, run update to generate it
RUN set -eux; \
    export COMPOSER_HOME="$(mktemp -d)"; \
    composer config apcu-autoloader true; \
    composer update --optimize-autoloader --apcu-autoloader --no-dev --no-scripts; \
    rm -rf "$COMPOSER_HOME"

# Configure Apache DocumentRoot for Symfony public directory and fix ALL logging
RUN sed -i 's!/var/www/html!/var/www/html/public!g' /etc/apache2/sites-available/000-default.conf && \
    # Fix all log directives to use stdout/stderr
    sed -i 's!ErrorLog.*!ErrorLog /dev/stderr!' /etc/apache2/sites-available/000-default.conf && \
    sed -i 's!CustomLog.*!CustomLog /dev/stdout combined!' /etc/apache2/sites-available/000-default.conf && \
    sed -i 's!ErrorLog.*!ErrorLog /dev/stderr!' /etc/apache2/sites-available/default-ssl.conf 2>/dev/null || true && \
    sed -i 's!CustomLog.*!CustomLog /dev/stdout combined!' /etc/apache2/sites-available/default-ssl.conf 2>/dev/null || true && \
    # Disable the other-vhosts-access-log configuration that causes permission issues
    a2disconf other-vhosts-access-log 2>/dev/null || true

# Quant Host header override (VirtualHost include approach)
RUN cat <<'EOF' > /etc/apache2/conf-available/quant-host-snippet.conf
<IfModule mod_rewrite.c>
    RewriteEngine On
    # Only accept well-formed hosts (optional port)
    RewriteCond %{HTTP:Quant-Orig-Host} ^([A-Za-z0-9.-]+(?::[0-9]+)?)$ [NC]
    RewriteRule ^ - [E=QUANT_HOST:%1]
</IfModule>
RequestHeader set Host "%{QUANT_HOST}e" env=QUANT_HOST
EOF

RUN a2enconf quant-host-snippet

RUN sed -i '/DocumentRoot \/var\/www\/html\/public/a\\n\t# Quant Host header override\n\tIncludeOptional /etc/apache2/conf-enabled/quant-host-snippet.conf' /etc/apache2/sites-available/000-default.conf

# Include Quant config include (synced into site root at runtime)
COPY quant/ /quant/
RUN chmod +x /quant/entrypoints.sh && \
    if [ -d /quant/entrypoints ]; then chmod +x /quant/entrypoints/* 2>/dev/null || true; fi

# Copy Quant PHP configuration files (allows users to add custom PHP configs)
COPY quant/php.ini.d/* /usr/local/etc/php/conf.d/

# Set up permissions
RUN usermod -a -G www-data nobody && \
    usermod -a -G root nobody && \
    usermod -a -G www-data root

# Copy source code (changes frequently - do this last!)
COPY src/ /var/www/html/

# Final setup that depends on source code
RUN set -eux; \
    # Run the Composer scripts that were skipped during install
    export COMPOSER_HOME="$(mktemp -d)"; \
    # Clear and warmup Symfony cache for production
    export APP_ENV=prod; \
    export APP_SECRET=build-time-secret-replaced-at-runtime; \
    php bin/console cache:clear --env=prod --no-debug || true; \
    php bin/console cache:warmup --env=prod --no-debug || true; \
    composer dump-autoload --optimize --apcu --no-dev; \
    rm -rf "$COMPOSER_HOME"; \
    # Set up permissions for Symfony var directory
    mkdir -p /var/www/html/var/cache /var/www/html/var/log; \
    chown -R www-data:www-data /var/www/html/var; \
    chmod -R 775 /var/www/html/var

# Set PATH
ENV PATH=${PATH}:/var/www/html/vendor/bin:/var/www/html/bin

# Expose ports
EXPOSE 80

# Use Quant entrypoints as the main entrypoint
ENTRYPOINT ["/quant/entrypoints.sh", "docker-php-entrypoint"]
CMD ["apache2-foreground"]
