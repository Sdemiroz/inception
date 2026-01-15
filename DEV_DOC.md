# DEV_DOC — Inception

## Prerequisites
- Docker Engine + Docker Compose v2
- A domain pointing to your local IP (for local testing, `/etc/hosts` is enough)

## Configuration files
- `srcs/docker-compose.yml` — the stack definition (services, volumes, network, secrets)
- `srcs/.env` — non-secret configuration (domain name, DB name/user, volume path)
- `secrets/*.txt` — local secret files (passwords), ignored by git

## Initial setup (from scratch)
1. Update `srcs/.env` for your login:
   - `DOMAIN_NAME=<login>.42.fr`
   - `WP_URL=https://<login>.42.fr`
   - `DATA_PATH=/home/<login>/data`
2. Point the domain to your host (example):
   - `127.0.0.1 <login>.42.fr`
3. Create secrets:
   - `bash scripts/init_secrets.sh`
4. Build and run:
   - `make up`

## Useful commands
- Inspect config: `docker compose -f srcs/docker-compose.yml config`
- List containers: `docker compose -f srcs/docker-compose.yml ps`
- Follow logs: `docker compose -f srcs/docker-compose.yml logs -f`
- Exec into a container: `docker compose -f srcs/docker-compose.yml exec wordpress bash`
- Remove everything created by compose: `make clean`

## Data persistence
The compose volumes are configured to bind to:
- `${DATA_PATH}/db` for MariaDB data
- `${DATA_PATH}/wp` for WordPress files

This keeps data across container rebuilds and restarts.
