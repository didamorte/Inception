#!/bin/bash

set -e

# Read secrets
MYSQL_PASSWORD=$(cat /run/secrets/mdb_password)
WP_ADMIN_PASSWORD=$(cat /run/secrets/wp_admin_password)
WP_USER_PASSWORD=$(cat /run/secrets/wp_user_password)

# Check required variables
: "${MYSQL_DATABASE:?MYSQL_DATABASE is not set}"
: "${MYSQL_USER:?MYSQL_USER is not set}"
: "${DOMAIN_NAME:?DOMAIN_NAME is not set}"
: "${WP_TITLE:?WP_TITLE is not set}"
: "${WP_ADMIN_USER:?WP_ADMIN_USER is not set}"
: "${WP_ADMIN_EMAIL:?WP_ADMIN_EMAIL is not set}"

cd /var/www/html

# Wait for MariaDB
echo "Waiting for MariaDB..."

until mysqladmin ping \
    -h mariadb \
    -u"${MYSQL_USER}" \
    -p"${MYSQL_PASSWORD}" \
    --silent
do
    sleep 1
done

echo "MariaDB is ready."

# Download WordPress if it is not already installed
if [ ! -f /var/www/html/wp-load.php ]; then
    echo "Installing WordPress files..."

    curl -fsSL \
        https://wordpress.org/latest.tar.gz \
        -o /tmp/wordpress.tar.gz

    tar -xzf /tmp/wordpress.tar.gz -C /tmp

    cp -r /tmp/wordpress/. /var/www/html/

    rm -rf /tmp/wordpress
    rm -f /tmp/wordpress.tar.gz

    echo "WordPress files installed."
fi

# PHP-FPM directory
mkdir -p /run/php

# Fix permissions
chown -R www-data:www-data /var/www/html
chown -R www-data:www-data /run/php

# Create wp-config.php
if [ ! -f /var/www/html/wp-config.php ]; then
    echo "Creating wp-config.php..."

    cp /var/www/html/wp-config-sample.php \
       /var/www/html/wp-config.php

    sed -i "s/database_name_here/${MYSQL_DATABASE}/" \
        /var/www/html/wp-config.php

    sed -i "s/username_here/${MYSQL_USER}/" \
        /var/www/html/wp-config.php

    sed -i "s/password_here/${MYSQL_PASSWORD}/" \
        /var/www/html/wp-config.php

    sed -i "s/localhost/mariadb/" \
        /var/www/html/wp-config.php
fi

# Add WordPress URL configuration
if ! grep -q "WP_HOME" /var/www/html/wp-config.php; then
    cat >> /var/www/html/wp-config.php <<EOF

define('WP_HOME', 'https://${DOMAIN_NAME}');
define('WP_SITEURL', 'https://${DOMAIN_NAME}');
EOF
fi

# Install WordPress
if ! wp core is-installed \
    --allow-root \
    --path=/var/www/html \
    >/dev/null 2>&1
then
    echo "Installing WordPress database..."

    wp core install \
        --allow-root \
        --path=/var/www/html \
        --url="https://${DOMAIN_NAME}" \
        --title="${WP_TITLE}" \
        --admin_user="${WP_ADMIN_USER}" \
        --admin_password="${WP_ADMIN_PASSWORD}" \
        --admin_email="${WP_ADMIN_EMAIL}"

    echo "WordPress database installed."
fi

# Create normal WordPress user
if wp core is-installed \
    --allow-root \
    --path=/var/www/html \
    >/dev/null 2>&1
then
    if [ -n "${WP_USER:-}" ]; then
        if ! wp user get "${WP_USER}" \
            --allow-root \
            --path=/var/www/html \
            >/dev/null 2>&1
        then
            echo "Creating WordPress user..."

            wp user create \
                "${WP_USER}" \
                "${WP_USER_EMAIL}" \
                --allow-root \
                --path=/var/www/html \
                --user_pass="${WP_USER_PASSWORD}" \
                --role="${WP_USER_ROLE:-author}"
        fi
    fi
fi

# Fix permissions one last time
chown -R www-data:www-data /var/www/html

echo "Starting PHP-FPM..."

exec php-fpm8.2 -F