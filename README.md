*This project has been created as part of the 42 curriculum by diogribe*

# Description
Inception is a system‑administration project whose goal is to set up a small infrastructure composed of different services using Docker Compose. The stack consists of three services:

* **NGINX** - acts as a TLS‑terminating reverse proxy (only port 443, TLS 1.2/1.3)
* **WordPress + PHP‑FPM** - the blog platform (no NGINX inside)
* **MariaDB** - the relational database for WordPress

Each service runs in its own container, built from a custom Dockerfile based on a Debian (or Alpine) image. Containers communicate through a user‑defined bridge network, persist data via named Docker volumes, and are restarted automatically on failure. Sensitive data (passwords) are handled via Docker Secrets, while non‑configuration values are stored in a `.env` file that is ignored by Git.

# Instructions
## Prerequisites
* A Linux machine with Docker Engine and Docker Compose installed.
* The current user must be able to run Docker commands (typically by being in the `docker` group).

## Build and start the stack
```bash
# Clone the repository (if not already done)
git clone <repository‑url>
cd <repository‑dir>

# Build the images and launch the containers in detached mode
docker compose -f srcs/docker-compose.yml up -d --build
```

## Verify the installation
* The WordPress site should be reachable at `https://<login>.42.fr` (replace `<login>` with your 42 login).  
  Add an entry to `/etc/hosts` or your local DNS if needed:
  ```
  127.0.0.1   <login>.42.fr
  ```
* To check the running containers:
  ```bash
  docker compose -f srcs/docker-compose.yml ps
  ```
* To stop the stack:
  ```bash
  docker compose -f srcs/docker-compose.yml down
  ```
* To stop and remove all volumes (data will be lost):
  ```bash
  docker compose -f srcs/docker-compose.yml down -v
  ```

## Managing secrets
The secrets are stored as plain files under `srcs/secrets/` and are **not** tracked by Git (see `.gitignore`).  
To change a secret:
1. Edit the corresponding file in `srcs/secrets/` (e.g., `mdb_root_password.txt`).
2. Re‑build and recreate the affected service:
   ```bash
   docker compose -f srcs/docker-compose.yml up -d --build <service>
   ```
   (Replace `<service>` with `mariadb`, `wordpress`, or `nginx` as needed.)

## Cleaning up
* Remove containers, network and images defined by the Compose file:
  ```bash
  docker compose -f srcs/docker-compose.yml down --rmi all --volumes --remove-orphans
  ```

# Resources
* Docker documentation: https://docs.docker.com/
* Docker Compose reference: https://docs.docker.com/compose/
* Docker Secrets: https://docs.docker.com/engine/swarm/secrets/
* NGINX TLS configuration: https://nginx.org/en/docs/http/configuring_https_servers.html
* WordPress Docker official image: https://hub.docker.com/_/wordpress
* MariaDB Docker official image: https://hub.docker.com/_/mariadb
* Official Debian images: https://hub.docker.com/_/debian
* Official Alpine Linux images: https://hub.docker.com/_/alpine
* A little AI to help with readmes and overview verifications

# Project description
## Why Docker instead of a classic Virtual Machine?
* **Performance** – containers share the host OS kernel, resulting in near‑native speed and lower memory/CPU overhead compared to full virtualization.
* **Start‑up time** – containers start in seconds, whereas VMs may need minutes to boot a full OS.
* **Image portability** – a Docker image bundles the application and its dependencies, guaranteeing the same behaviour on any host with Docker.
* **Isolation** – while weaker than a VM, containers still provide process and filesystem isolation suitable for isolating services.
* **Ecosystem** – Docker Hub, Compose, Swarm, and Kubernetes provide a rich toolbox for lifecycle management.

## Secrets vs. Environment Variables
* **Environment variables** are easy to use but are visible to all processes inside the container (via `ps e`) and are stored in the image layers if defined via `ENV`; they are also logged by many agents.
* **Docker secrets** are mounted as temporary files (`/run/secrets/<name>`) and are only accessible to the container’s root processes (by default). They are not stored in the image layer and are transmitted securely over TLS when using Swarm mode. For a single‑node setup (as in this project) file‑based secrets provide a good balance of security and simplicity.
* In this project, passwords are stored as secrets; non‑sensitive configuration (domain name, database names, usernames) stays in the `.env` file (environment variables).

## Docker Network vs. Host Network
* **Host network** (`network_mode: host`) removes network isolation, giving the container full access to the host’s network interfaces and ports. This can lead to port conflicts and reduces security.
* **User‑defined bridge network** (used here) provides isolation: containers can only communicate with each other via the network’s internal IP range, and ports are exposed only when explicitly published (`ports:`). This enables fine‑grained control over which services are reachable from the outside (only NGINX on 443).

## Docker Volumes vs. Bind Mount
* **Bind mounts** (`host_path:container_path`) tie a specific host directory into the container. They are useful for development because changes on the host are instantly visible inside the container, but they make the container dependent on the host’s directory structure and can expose host files unintentionally.
* **Named volumes** are managed by Docker; Docker decides where to store the data (usually under `/var/lib/docker/volumes/`). They are portable, can be shared between containers, and let Docker handle lifecycle (backup, prune, etc.).
* In this project we used **named volumes** with the `local` driver and explicit `device`/`o: bind` options to satisfy the requirement that the data be stored under `/home/<login>/data` on the host while still benefiting from volume management (backup, portability, etc.).

