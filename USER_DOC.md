# USER_DOC — Inception

## Services provided
- `nginx` (TLS reverse proxy, port 443 only)
- `wordpress` (php-fpm, internal port 9000)
- `mariadb` (database, internal port 3306)

## Start/stop
- Start: `make up`
- Stop: `make down`
- Stop + remove Docker volumes: `make clean`

## Access the website and admin panel
- Website: `https://sdemiroz.42.fr`
- Admin panel: `https://sdemiroz.42.fr/wp-admin`

The TLS certificate is self-signed, so your browser will display a warning.

## Credentials and secrets
Credentials are stored as local Docker secrets files (not committed):
- `secrets/db_root_password.txt`
- `secrets/db_password.txt`
- `secrets/wp_admin_password.txt`
- `secrets/wp_user_password.txt`

Create them with: `bash scripts/init_secrets.sh`

## Check services are running
- `docker compose -f srcs/docker-compose.yml ps`
- `docker compose -f srcs/docker-compose.yml logs -f nginx`
- `docker compose -f srcs/docker-compose.yml logs -f wordpress`
- `docker compose -f srcs/docker-compose.yml logs -f mariadb`

## Persistent data location
On the host:
- Database: `/home/sdemiroz/data/db`
- WordPress files: `/home/sdemiroz/data/wp`
