FROM debian:bullseye

RUN apt-get update && apt-get install -y --no-install-recommends \
    nginx \
    openssl \
    gettext-base \
    && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /etc/nginx/ssl /var/www/html

COPY conf/nginx.conf /etc/nginx/nginx.conf.template
COPY conf/entrypoint.sh /usr/local/bin/entrypoint.sh

RUN chmod +x /usr/local/bin/entrypoint.sh

EXPOSE 443

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
