# Inception — Step-by-step implementation guide (mandatory)

This guide describes the logical build order for the stack in `srcs/`, what each part
does, why it exists (per subject), and what to read next when you want deeper details.

## 0) Goal and invariants (what must always be true)

- **Only NGINX is public**: only port **443** is published to the host.
- **TLS only**: NGINX must speak **TLSv1.2/TLSv1.3**.
- **WordPress is php-fpm only**: no nginx/apache inside the WordPress container.
- **MariaDB only**: database container runs only MariaDB.
- **Services talk on a Docker network**: no `network_mode: host`, no `links:`.
- **Persistence**: database files and WordPress files survive rebuilds via volumes bound
  to `/home/<login>/data`.
- **No “keep container alive” hacks**: no `tail -f`, `sleep infinity`, `while true`.
  PID 1 should be the real service process (`mysqld`, `php-fpm`, `nginx`).
- **No passwords in git**: secrets live in local files mounted as Docker secrets.

## 1) Scaffold first: `.env`, secrets, Compose

### 1.1 `.env` (non-secret configuration)
File: `srcs/.env`

What it is:
- A plain key/value file loaded by Docker Compose and by the `Makefile`.

What it contains (and why):
- `DOMAIN_NAME`, `WP_URL`: lets NGINX and WordPress agree on the site URL.
- `DB_NAME`, `DB_USER`: database name and user (non-secret).
- `DATA_PATH`: where host persistence lives (`/home/<login>/data`).
- `WP_ADMIN_*`, `WP_USER_*`: usernames/emails (non-secret). Passwords are secrets.

Read more:
- Docker Compose env files: https://docs.docker.com/compose/environment-variables/

### 1.2 Secrets (passwords as files, not in git)
Files:
- Generator: `scripts/init_secrets.sh`
- Local secrets directory: `secrets/`
- Git ignore: `.gitignore`

How it works:
- `scripts/init_secrets.sh` creates `secrets/*.txt` with random values (mode `0600`).
- `srcs/docker-compose.yml` mounts them into containers as `/run/secrets/<name>`.
- Containers read passwords from those files at runtime.

Why this matters:
- The subject requires **no credentials in the repository** and recommends secrets.

Read more:
- Docker secrets (Compose): https://docs.docker.com/compose/use-secrets/

### 1.3 `docker-compose.yml` (the contract between services)
File: `srcs/docker-compose.yml`

What to implement first in Compose:
1) **Network**: a user-defined bridge network called `inception`
2) **Volumes**: bind-backed volumes pointing to `${DATA_PATH}/db` and `${DATA_PATH}/wp`
3) **Secrets**: map local `secrets/*.txt` into Docker secrets
4) **Services**:
   - `mariadb` (internal 3306 only)
   - `wordpress` (expose 9000 only)
   - `nginx` (publish 443:443 only)

Key fields (what they mean):
- `image`: required by the subject (“each image must have same name as service”).
- `build.context`: points to your Dockerfile directory (you build your own images).
- `restart: always`: containers restart if the process crashes.
- `depends_on`: start order (note: does not guarantee readiness).
- `networks`: attaches containers to the same internal network for DNS by service name.
- `volumes`: persistence across rebuilds; WordPress and MariaDB keep data.
- `secrets`: mounts secrets as files under `/run/secrets/`.

Read more:
- Compose file reference: https://docs.docker.com/compose/compose-file/
- Docker networks: https://docs.docker.com/network/
- Docker volumes: https://docs.docker.com/storage/volumes/

## 2) MariaDB (first running service)

### 2.1 Dockerfile
File: `srcs/requirements/mariadb/Dockerfile`

What it does:
- Starts from Debian (allowed by subject).
- Installs `mariadb-server` and `mariadb-client`.
- Copies a custom entrypoint script.

Why an entrypoint:
- MariaDB needs **one-time initialization** on an empty volume.
- We must do it without “sleep loops” and end with `mysqld` as PID 1.

Read more:
- MariaDB server docs: https://mariadb.com/kb/en/documentation/

### 2.2 Entrypoint (init-once + run forever)
File: `srcs/requirements/mariadb/tools/entrypoint.sh`

Logical flow:
1) Validate required env + secret-file paths.
2) Ensure ownership of `/var/lib/mysql` is `mysql:mysql` (common bind-mount issue).
3) If `/var/lib/mysql/mysql` is missing, run `mariadb-install-db`.
4) Update `bind-address` to `0.0.0.0` so other containers can connect.
5) If marker file `.inception_initialized` is missing:
   - start a temporary `mysqld` with `--skip-networking` (socket-only)
   - set root password, create DB, create WP user, grant privileges
   - shutdown the temporary server
   - write `.inception_initialized` to avoid re-running on next boot
6) `exec mysqld ...` in the foreground (this becomes PID 1).

Why the marker file:
- With a persistent volume, container restarts should not re-create users/DB each time.

Read more:
- “PID 1 in containers”: https://docs.docker.com/engine/containers/multi-service_container/

## 3) WordPress + php-fpm (second running service)

### 3.1 Dockerfile
File: `srcs/requirements/wordpress/Dockerfile`

What it does:
- Installs `php-fpm` + MySQL extension (`php8.2-mysql`) and a MySQL client.
- Adjusts php-fpm to listen on `0.0.0.0:9000` (so NGINX can reach it).
- Installs `wp-cli` (used to download/configure WordPress on first boot).
- Copies an entrypoint script.

Read more:
- PHP-FPM: https://www.php.net/manual/en/install.fpm.php
- WP-CLI: https://wp-cli.org/

### 3.2 Entrypoint (wait-for-db + install-once)
File: `srcs/requirements/wordpress/tools/entrypoint.sh`

Logical flow:
1) Read secrets from `/run/secrets/*`.
2) Read required env (`WORDPRESS_DB_*`, `WP_*`).
3) Enforce the subject rule: admin username must not contain `admin` (case-insensitive).
4) Wait until MariaDB is reachable (bounded retry, not infinite).
5) If `/var/www/html/wp-config.php` is missing:
   - `wp core download`
   - `wp config create` (writes `wp-config.php` with DB creds)
   - `wp core install` (creates tables and the admin user)
   - `wp user create` (creates the second user)
6) Ensure correct ownership (`www-data`) and `exec php-fpm -F`.

Why the WordPress volume matters:
- `/var/www/html` is mounted from `wordpress_files`, so the site persists.

## 4) NGINX (last running service; only public entry)

### 4.1 Dockerfile
File: `srcs/requirements/nginx/Dockerfile`

What it does:
- Installs `nginx` + `openssl`.
- Copies a config template and entrypoint.
- Runs NGINX in foreground via entrypoint (PID 1 = nginx master).

Read more:
- NGINX docs: https://nginx.org/en/docs/
- NGINX + FastCGI (php-fpm): https://nginx.org/en/docs/http/ngx_http_fastcgi_module.html
- TLS config basics: https://nginx.org/en/docs/http/configuring_https_servers.html

### 4.2 Entrypoint (generate TLS + render vhost)
File: `srcs/requirements/nginx/tools/entrypoint.sh`

Logical flow:
1) Read `DOMAIN_NAME` from env.
2) Create a self-signed certificate if none exists in `/etc/nginx/ssl`.
3) Render `default.conf.template` by replacing `__DOMAIN_NAME__`.
4) `exec nginx -g 'daemon off;'`.

Why templating:
- Keeps the config generic and driven by `.env` (matches subject style).

### 4.3 NGINX vhost template
File: `srcs/requirements/nginx/tools/default.conf.template`

Important directives:
- `listen 443 ssl;` and `ssl_protocols TLSv1.2 TLSv1.3;` (subject requirement).
- `server_name __DOMAIN_NAME__;` (domain must match).
- `if ($host != "__DOMAIN_NAME__") { return 444; }` (drops unexpected Host headers).
- `fastcgi_pass wordpress:9000;` (DNS name = Compose service name on the network).

## 5) Makefile (orchestration on the host)

File: `Makefile`

What it does:
- Reads `srcs/.env` to get `DATA_PATH`.
- Checks secret files exist before bringing the stack up.
- Creates `${DATA_PATH}/db` and `${DATA_PATH}/wp` on the host (bind mount targets).
- Runs `docker compose -f srcs/docker-compose.yml up -d --build`.

Why this is useful in defense:
- One command to reproduce the whole stack (subject requirement).

Read more:
- GNU Make basics: https://www.gnu.org/software/make/manual/make.html

## 6) Minimal validation checklist (what to test after each step)

After Compose is written:
- `docker compose -f srcs/docker-compose.yml config` (ensure variables resolve)

After MariaDB is added:
- `docker compose -f srcs/docker-compose.yml up -d --build mariadb`
- `docker compose -f srcs/docker-compose.yml logs -f mariadb`

After WordPress is added:
- `docker compose -f srcs/docker-compose.yml up -d --build wordpress`
- `docker compose -f srcs/docker-compose.yml logs -f wordpress`

After NGINX is added:
- `docker compose -f srcs/docker-compose.yml up -d --build`
- Confirm only port mapping is `443:443`:
  - `docker compose -f srcs/docker-compose.yml ps`

When debugging:
- `docker compose -f srcs/docker-compose.yml exec mariadb mariadb -uroot -p`
- `docker compose -f srcs/docker-compose.yml exec wordpress php -v`
- `docker compose -f srcs/docker-compose.yml exec nginx nginx -t`

## 7) Where to learn more (high-value topics for defense)

- Docker architecture, images vs containers: https://docs.docker.com/get-started/
- Build best practices: https://docs.docker.com/develop/develop-images/dockerfile_best-practices/
- Compose networking and DNS: https://docs.docker.com/compose/networking/
- Volumes vs bind mounts: https://docs.docker.com/storage/
- TLS basics + self-signed certs (NGINX): https://nginx.org/en/docs/http/configuring_https_servers.html
- MariaDB initialization patterns: https://mariadb.com/kb/en/mariadb-install-db/
- WordPress hardening basics (later): https://wordpress.org/support/article/hardening-wordpress/
