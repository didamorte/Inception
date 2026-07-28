# User Documentation

This document explains how an end user or administrator can interact with the Inception project.

## Services Provided

The Inception stack consists of three services:

- **NGINX**: Acts as a TLS-terminating reverse proxy, listening on port 443 (HTTPS) and forwarding requests to WordPress.
- **WordPress + PHP-FPM**: The blog platform, accessible via the web server.
- **MariaDB**: The relational database used by WordPress for storing content, users, settings, etc.

Each service runs in its own isolated container, communicating via a user-defined bridge network (`inception`). Data persistence is achieved through named Docker volumes, and sensitive credentials are managed via Docker secrets.

## Starting and Stopping the Project

The project can be managed using the provided Makefile or directly with Docker Compose.

### Using Makefile

- **Start the stack** (build images and start containers in detached mode):
  ```bash
  make
  ```
  or equivalently:
  ```bash
  make up
  ```

- **Stop the stack** (stop containers, remove network):
  ```bash
  make down
  ```

- **Stop and remove everything** (containers, network, volumes, and images):
  ```bash
  make fclean
  ```

- **Rebuild and restart** (equivalent to `fclean` then `up`):
  ```bash
  make re
  ```

## Accessing the Website and Administration Panel

Once the stack is running, the WordPress site is accessible via HTTPS at the domain specified in `srcs/requirements/.env` (variable `DOMAIN_NAME`). By default, this is set to `diogribe.42.fr`.

To access the site:
1. Ensure your machine can resolve the domain name. You may need to add an entry to your `/etc/hosts` file (or equivalent) pointing the domain to `127.0.0.1`:
   ```
   127.0.0.1   diogribe.42.fr
   ```
2. Open a web browser and navigate to `https://diogribe.42.fr`.
   - Note: The site uses a self-signed SSL certificate; your browser may show a warning. You will need to proceed past this warning (advanced → proceed anyway) for development purposes.

The WordPress administration panel is available at:
`https://diogribe.42.fr/wp-admin`

Log in using the credentials set in the secrets:
- Administrator username: `WP_ADMIN_USER` (from `srcs/requirements/.env`)
- Administrator password: stored in `srcs/secrets/wp_admin_password.txt`

## Locating and Managing Credentials

The project separates sensitive credentials (passwords) from non-sensitive configuration.

### Sensitive Credentials (Secrets)
The following passwords are managed as Docker secrets and stored as files in `srcs/secrets/`:
- `mdb_root_password.txt`: Root password for MariaDB.
- `mdb_password.txt`: Password for the WordPress MariaDB user.
- `wp_admin_password.txt`: Password for the WordPress administrator user.
- `wp_user_password.txt`: Password for the additional WordPress user (role defined by `WP_USER_ROLE` in `.env`).

These files are **not** tracked by Git (see `.gitignore`). To change a secret:
1. Edit the corresponding file in `srcs/secrets/` (e.g., update the password inside the file).
2. Recreate the affected service(s) to pick up the new secret:
   ```bash
   docker compose -f srcs/docker-compose.yml up -d --build <service>
   ```
   Replace `<service>` with `mariadb`, `wordpress`, or `nginx` as needed. For example, to update the MariaDB root password, restart the mariadb service:
   ```bash
   docker compose -f srcs/docker-compose.yml up -d --build mariadb
   ```

### Non-Sensitive Configuration
Non-sensitive settings (domain name, database names, usernames, etc.) are stored in `srcs/requirements/.env`. This file is also ignored by Git. Edit this file to change:
- `DOMAIN_NAME`: The fully qualified domain name for the site.
- `MYSQL_DATABASE`: The WordPress database name.
- `MYSQL_USER`: The MariaDB user for WordPress.
- `WP_ADMIN_USER`: The WordPress administrator username.
- `WP_USER`: The additional WordPress username.
- `WP_USER_EMAIL`: Email for the additional user.
- `WP_USER_ROLE`: Role for the additional user (e.g., editor, author).
- `WP_TITLE`: The site title displayed in WordPress.

After modifying `.env`, you must rebuild and restart the services for the changes to take effect:
```bash
docker compose -f srcs/docker-compose.yml up -d --build
```

## Verifying Services Are Running

You can verify that the services are running correctly in several ways:

### 1. Check Container Status
```bash
docker compose -f srcs/docker-compose.yml ps
```
You should see three containers (mariadb, wordpress, nginx) with a state of "Up".

### 2. Check Container Logs
To see real-time logs for a service:
```bash
docker compose -f srcs/docker-compose.yml logs -f <service>
```
Replace `<service>` with the service name (e.g., `wordpress`). Press `Ctrl+C` to stop following logs.

### 3. Test Website Access
As described above, navigate to `https://diogribe.42.fr` in a browser. The site should load without connection errors (ignoring the self-signed certificate warning).

### 4. Check Service Ports
NGINX should be listening on port 443 (verified by attempting to connect or using `docker compose port nginx 443`).

### 5. Volume Mounts
Data persistence can be verified by checking that the directories `/home/diogribe/data/mariadb` and `/home/diogribe/data/wordpress` exist and contain data after the stack has been running.

## Stopping and Cleaning Up

- To temporarily stop the stack while preserving data (volumes): `make down` or `docker compose down`.
- To stop and remove all data (volumes): `make fclean` or `docker compose down -v`.
- To also remove built images: add `--rmi all` to the down command.

## Support and Resources

For more information on the technologies used, refer to the Resources section in the main README.md.

