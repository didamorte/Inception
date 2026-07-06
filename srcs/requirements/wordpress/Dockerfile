FROM debian:bullseye

RUN apt-get update && apt-get install -y --no-install-recommends \
    php-fpm \
    php-cli \
    php-mysql \
    curl \
    mariadb-client \
    ca-certificates \
    tar \
    unzip \
    && rm -rf /var/lib/apt/lists/*

RUN curl -fsSL https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar -o /usr/local/bin/wp \
    && chmod +x /usr/local/bin/wp

RUN mkdir -p /run/php /var/www/html \
    && sed -i 's|^listen = .*|listen = 9000|' /etc/php/7.4/fpm/pool.d/www.conf \
    && chown -R www-data:www-data /run/php /var/www/html

COPY conf/entrypoint.sh /usr/local/bin/entrypoint.sh

RUN chmod +x /usr/local/bin/entrypoint.sh

EXPOSE 9000

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
