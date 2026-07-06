#!/bin/sh
set -e

if [ -z "${DOMAIN_NAME}" ]; then
    echo "DOMAIN_NAME is not set" >&2
    exit 1
fi

if [ ! -f /etc/nginx/ssl/nginx.crt ] || [ ! -f /etc/nginx/ssl/nginx.key ]; then
    openssl req -x509 -nodes -days 365 \
        -newkey rsa:2048 \
        -keyout /etc/nginx/ssl/nginx.key \
        -out /etc/nginx/ssl/nginx.crt \
        -subj "/C=PT/ST=Lisbon/L=Lisbon/O=42/OU=Inception/CN=${DOMAIN_NAME}"
fi

envsubst '$DOMAIN_NAME' < /etc/nginx/nginx.conf.template > /etc/nginx/nginx.conf

exec nginx -g "daemon off;"
