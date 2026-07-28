# Developer Documentation

This document describes how a developer can set up the environment, build, and maintain the Inception project from scratch.

## Environment Setup

### Prerequisites
- A Linux machine (physical or virtual) with:
  - Docker Engine installed (version 20.10 or later recommended).
  - Docker Compose plugin (or standalone docker-compose) installed.
  - Git installed (to clone the repository).
- The user must be able to run Docker commands without sudo (typically by being added to the `docker` group).
- At least 2 GB of free disk space for images and volumes.

### Cloning the Repository
```bash
git clone <repository-url>
cd Inception   # or the directory name of the cloned repository
```

### Configuration Files
The project uses the following configuration files (all ignored by Git via `.gitignore`):

1. **`srcs/requirements/.env`**  
   Contains non-sensitive environment variables used by all services.  
   Key variables:
   - `DOMAIN_NAME`: The fully qualified domain name for the site (e.g., `jdoe.42.fr`).
   - `MYSQL_DATABASE`: Name of the WordPress database.
   - `MYSQL_USER`: MariaDB user for WordPress.
   - `WP_ADMIN_USER`: WordPress administrator username.
   - `WP_USER`: Additional WordPress username.
   - `WP_USER_EMAIL`: Email for the additional WordPress user.
   - `WP_USER_ROLE`: Role of the additional user (e.g., `editor`).
   - `WP_TITLE`: Site title displayed in WordPress.

2. **`srcs/secrets/`**  
   Directory containing files for Docker secrets (sensitive data):
   - `mdb_root_password.txt`: Root password for MariaDB.
   - `mdb_password.txt`: Password for the WordPress MariaDB user.
   - `wp_admin_password.txt`: Password for the WordPress administrator.
   - `wp_user_password.txt`: Password for the additional WordPress user.

   **Note:** These files must exist before building the images, as they are mounted as secrets at container startup.  
   Example content for each file is a plain string (the password) without trailing newline (though a newline is tolerated).

### Initial Setup
1. Copy the example environment file (if provided) or create `.env` from scratch:
   ```bash
   cp srcs/requirements/.env.example srcs/requirements/.env   # if an example exists
   # Otherwise, create the file manually with the required variables.
   ```
2. Create the secrets directory and files:
   ```bash
   mkdir -p srcs/secrets
   # Generate or set passwords, e.g.:
   openssl rand -base64 16 | tr -d '=\n' > srcs/secrets/mdb_root_password.txt
   openssl rand -base64 16 | tr -d '=\n' > srcs/secrets/mdb_password.txt
   openssl rand -base64 16 | tr -d '=\n' > srcs/secrets/wp_admin_password.txt
   openssl rand -base64 16 | tr -d '=\n' > srcs/secrets/wp_user_password.txt
   ```
   **Important:** The passwords must match the expectations of the WordPress installation (no special constraints beyond being non-empty).

3. Ensure the data directories exist on the host (the volumes will bind-mount to these paths):
   ```bash
   mkdir -p /home/$USER/data/mariadb
   mkdir -p /home/$USER/data/wordpress
   ```
   The docker-compose.yml defines volumes that bind to `/home/<login>/data/mariadb` and `/home/<login>/data/wordpress`. Replace `<login>` with your actual username (or adjust the volume definitions in docker-compose.yml if you prefer a different path).

## Building and Launching the Project

The project provides a Makefile for convenience, but all actions can be performed directly with Docker Compose.

### Using the Makefile
- **Build images and start containers** (detached):
  ```bash
  make up
  ```
  This is equivalent to `make` (since `all: up`).

- **Start without rebuilding** (if images are already built):
  ```bash
  make up   # still builds if Dockerfile changed; use docker compose directly to skip
  ```

### Using Docker Compose Directly
```bash
docker compose -f srcs/docker-compose.yml up -d --build
```
- The `--build` flag forces a rebuild of images; omit it if you only want to start existing images.
- To run in the foreground (for debugging): omit `-d`.
- To build without starting: `docker compose -f srcs/docker-compose.yml build`

## Managing Containers and Volumes

### Common Docker Compose Commands
| Command | Purpose |
|---------|---------|
| `docker compose -f srcs/docker-compose.yml ps` | List containers and their status. |
| `docker compose -f srcs/docker-compose.yml logs [service]` | View logs for a service (or all services). Use `-f` to follow. |
| `docker compose -f srcs/docker-compose.yml top` | Show running processes in containers. |
| `docker compose -f srcs/docker-compose.yml exec <service> <command>` | Run a command inside a running container (e.g., `exec wordpress wp core version`). |
| `docker compose -f srcs/docker-compose.yml stop` | Stop containers without removing them. |
| `docker compose -f srcs/docker-compose.yml start` | Start stopped containers. |
| `docker compose -f srcs/docker-compose.yml rm` | Remove stopped containers. |
| `docker compose -f srcs/docker-compose.yml down` | Stop containers, remove network, and optionally volumes/images. |

### Volume Management
The project uses named volumes that are bind-mounted to specific host directories:
- `mariadb_data`: mapped to `/home/<login>/data/mariadb`
- `wordpress_data`: mapped to `/home/<login>/data/wordpress`

To inspect or back up data:
- Ensure the stack is stopped (or at least not writing) to avoid inconsistencies.
- The data resides directly in the host directories listed above.
- To back up, copy the contents of these directories.
- To restore, replace the contents (with the stack stopped).

### Pruning Unused Resources
To remove dangling images, containers, and volumes not used by this project:
```bash
docker system prune -a   # use with caution; removes all unused objects
```
Or prune only specific types:
```bash
docker volume prune
docker image prune
```

## Data Persistence and Storage Locations

### Where Project Data Is Stored
- **MariaDB data**: Stored in the volume `mariadb_data`, which is bind-mounted to `/home/<login>/data/mariadb` on the host.
- **WordPress data** (uploads, themes, plugins, etc.): Stored in the volume `wordpress_data`, bind-mounted to `/home/<login>/data/wordpress`.
- **Configuration**: The Docker images themselves contain the application code and configuration; mutable configuration (like WordPress settings via admin panel) is stored in the database or within the WordPress volume (e.g., uploaded media, themes, plugins installed via WP admin).

### Persistence Behavior
- **Named volumes** persist data even after containers are removed (via `docker compose down` without the `-v` flag).
- If you run `docker compose down -v`, the named volumes are removed, and thus the data on the host bind-mounts is **not** automatically removed (because the volume driver specifies `device: /host/path`). However, note that the volume removal will delete the bind-mounted directory's contents? Actually, with the driver_opts `device: /host/path`, the volume is essentially a bind mount; removing the volume in Docker does not delete the host directory. It only removes the volume metadata. The host directory remains intact. To truly remove data, you must delete the host directory manually.
- Therefore, to persist data across redeploys, avoid using the `-v` flag with `down`. To start fresh, manually delete the contents of `/home/<login>/data/mariadb` and `/home/<login>/data/wordpress` (or the directories themselves) after stopping the stack.

### Backup and Restore
- **Backup**: Stop the stack, then copy the directories `/home/<login>/data/mariadb` and `/home/<login>/data/wordpress` to a backup location.
- **Restore**: Stop the stack, replace the contents of those directories with the backup, then start the stack.

## Useful Development Commands

### Accessing Shells in Containers
```bash
# MariaDB shell
docker compose -f srcs/docker-compose.yml exec mariadb mariadb -u root -p
# WordPress shell (bash)
docker compose -f srcs/docker-compose.yml exec wordpress bash
# NGINX shell (bash)
docker compose -f srcs/docker-compose.yml exec nginx bash
```

### Running WP-CLI Commands
WordPress includes WP-CLI in the wordpress container:
```bash
docker compose -f srcs/docker-compose.yml exec wordpress wp --info
docker compose -f srcs/docker-compose.yml exec wp core update
```

### Checking Service Health
You can use `docker compose ps` to see if containers are healthy (if healthchecks are defined). Currently, no healthchecks are defined, but you can check logs for startup errors.

### Rebuilding Specific Services
If you modify a Dockerfile or configuration for a specific service, rebuild only that service:
```bash
docker compose -f srcs/docker-compose.yml up -d --build <service>
```
Example: `docker compose -f srcs/docker-compose.yml up -d --build nginx`

## Troubleshooting

### Common Issues
- **Containers exit immediately**: Check logs with `docker compose logs <service>`. Common causes: missing secrets, permission errors on volumes, port conflicts.
- **Port 443 already in use**: Stop any existing process using port 443 (e.g., another web server) or change the port in docker-compose.yml (not recommended as it deviates from the project spec).
- **Website not loading**: Verify NGINX is running and listening on port 443 (`netstat -tlnp | grep :443` or `docker compose port nginx 443`). Check NGINX error logs: `docker compose logs nginx`.
- **Database connection failures**: Ensure MariaDB is running and the credentials in `.env` and secrets match. Check MariaDB logs: `docker compose logs mariadb`.

### Resetting the Environment
To start completely from scratch (remove images, volumes, and anonymous volumes):
```bash
docker compose -f srcs/docker-compose.yml down -v --rmi all --remove-orphans
```
Then remove the host data directories if desired:
```bash
rm -rf /home/$USER/data/mariadb /home/$USER/data/wordpress
```
Recreate the directories and restore secrets/.env as needed.

## Resources Consulted
During development, the following resources were referenced:
- Docker documentation: https://docs.docker.com/
- Docker Compose reference: https://docs.docker.com/compose/
- Docker Secrets: https://docs.docker.com/engine/swarm/secrets/
- NGINX configuration: https://nginx.org/en/docs/
- WordPress Docker image: https://hub.docker.com/_/wordpress
- MariaDB Docker image: https://hub.docker.com/_/mariadb
- WP-CLI: https://wp-cli.org/
- The 42 school project subject (Inception).
