#!/bin/bash

set -e

MYSQL_ROOT_PASSWORD=$(cat /run/secrets/mdb_root_password)
MYSQL_PASSWORD=$(cat /run/secrets/mdb_password)

mkdir -p /run/mysqld
chown -R mysql:mysql /run/mysqld /var/lib/mysql

# Check if this is a fresh database
if [ ! -d /var/lib/mysql/mysql ]; then
    echo "Initializing MariaDB..."

    mariadb-install-db \
        --user=mysql \
        --datadir=/var/lib/mysql

    FRESH_DB=true
else
    echo "MariaDB already initialized."
    FRESH_DB=false
fi

# Start temporary MariaDB
echo "Starting temporary MariaDB..."

mariadbd \
    --user=mysql \
    --datadir=/var/lib/mysql \
    --socket=/run/mysqld/mysqld.sock \
    --skip-networking &

pid=$!

# Wait for MariaDB
echo "Waiting for MariaDB..."

until mysqladmin \
    --socket=/run/mysqld/mysqld.sock \
    ping \
    --silent
do
    sleep 1
done

echo "MariaDB is ready."

# Configure database and users
if [ "$FRESH_DB" = true ]; then

    echo "Configuring fresh database..."

    mysql \
        --socket=/run/mysqld/mysqld.sock \
        -u root <<-EOSQL

        ALTER USER 'root'@'localhost'
            IDENTIFIED VIA mysql_native_password
            USING PASSWORD('${MYSQL_ROOT_PASSWORD}');

        CREATE DATABASE IF NOT EXISTS \`${MYSQL_DATABASE}\`;

        CREATE USER IF NOT EXISTS '${MYSQL_USER}'@'%'
            IDENTIFIED BY '${MYSQL_PASSWORD}';

        GRANT ALL PRIVILEGES ON \`${MYSQL_DATABASE}\`.*
            TO '${MYSQL_USER}'@'%';

        FLUSH PRIVILEGES;

EOSQL

else

    echo "Checking existing database configuration..."

    mysql \
        --socket=/run/mysqld/mysqld.sock \
        -u root \
        -p"${MYSQL_ROOT_PASSWORD}" <<-EOSQL

        ALTER USER 'root'@'localhost'
            IDENTIFIED VIA mysql_native_password
            USING PASSWORD('${MYSQL_ROOT_PASSWORD}');

        CREATE DATABASE IF NOT EXISTS \`${MYSQL_DATABASE}\`;

        CREATE USER IF NOT EXISTS '${MYSQL_USER}'@'%'
            IDENTIFIED BY '${MYSQL_PASSWORD}';

        ALTER USER '${MYSQL_USER}'@'%'
            IDENTIFIED BY '${MYSQL_PASSWORD}';

        GRANT ALL PRIVILEGES ON \`${MYSQL_DATABASE}\`.*
            TO '${MYSQL_USER}'@'%';

        FLUSH PRIVILEGES;

EOSQL

fi

echo "Database and user configuration complete."

# Stop temporary MariaDB
mysqladmin \
    --socket=/run/mysqld/mysqld.sock \
    -u root \
    -p"${MYSQL_ROOT_PASSWORD}" \
    shutdown

wait "$pid"

echo "Starting MariaDB normally..."

exec mariadbd \
    --user=mysql \
    --datadir=/var/lib/mysql \
    --socket=/run/mysqld/mysqld.sock \
    --bind-address=0.0.0.0