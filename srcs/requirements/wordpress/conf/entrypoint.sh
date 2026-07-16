#!/bin/bash
set -e

# Read secrets
MYSQL_PASSWORD=$(cat /run/secrets/mdb_password)
WP_ADMIN_PASSWORD=$(cat /run/secrets/wp_admin_password)
WP_USER_PASSWORD=$(cat /run/secrets/wp_user_password)

cd /var/www/html

until mysqladmin ping -h mariadb -u"${MYSQL_USER}" -p"${MYSQL_PASSWORD}" --silent; do
    sleep 1
done

if [ ! -f /var/www/html/wp-load.php ]; then
    curl -fsSL https://wordpress.org/latest.tar.gz -o /tmp/wordpress.tar.gz
    tar -xzf /tmp/wordpress.tar.gz -C /tmp
    cp -r /tmp/wordpress/. /var/www/html/
    rm -rf /tmp/wordpress /tmp/wordpress.tar.gz
fi

mkdir -p /run/php
chown -R www-data:www-data /var/www/html /run/php

if [ ! -f /var/www/html/wp-config.php ]; then
    cp wp-config-sample.php wp-config.php
    sed -i "s/database_name_here/${MYSQL_DATABASE}/" wp-config.php
    sed -i "s/username_here/${MYSQL_USER}/" wp-config.php
    sed -i "s/password_here/${MYSQL_PASSWORD}/" wp-config.php
    sed -i "s/localhost/mariadb/" wp-config.php
fi

if ! grep -q "WP_HOME" wp-config.php; then
    cat <<EOFF >> wp-config.php
define('WP_HOME', 'https://${DOMAIN_NAME}');
define('WP_SITEURL', 'https://${DOMAIN_NAME}');
EOFF
fi

if ! wp core is-installed --allow-root --path=/var/www/html >/dev/null 2>&1; then
    wp core install --allow-root --path=/var/www/html \
        --url="https://${DOMAIN_NAME}" \
        --title="${WP_TITLE}" \
        --admin_user="${WP_ADMIN_USER}" \
        --admin_password="${WP_ADMIN_PASSWORD}" \
        --admin_email="${WP_ADMIN_EMAIL}"
fi

if wp core is-installed --allow-root --path=/var/www/html >/dev/null 2>&1; then
    if [ -n "${WP_USER}" ] && ! wp user get "${WP_USER}" --allow-root --path=/var/www/html >/dev/null 2>&1; then
        wp user create "${WP_USER}" "${WP_USER_EMAIL}" \
            --allow-root \
            --path=/var/www/html \
            --user_pass="${WP_USER_PASSWORD}" \
            --role="${WP_USER_ROLE:-author}"
    fi
fi

exec php-fpm8.2 -F
