*This project has been created as part of the 42 curriculum by sdemiroz.*

## Description
Inception is a small Docker-based infrastructure running:
- **NGINX** as the only public entry point on **443** with **TLSv1.2/TLSv1.3**
- **WordPress** running on **php-fpm** only (no web server inside the container)
- **MariaDB** as the database

The services communicate over an isolated Docker network and persist data via volumes
bound to `/home/<login>/data`.

## Instructions
1. Set your domain in `/etc/hosts` (replace with your login):
   - `127.0.0.1 sdemiroz.42.fr`
2. Create required secrets locally:
   - `bash scripts/init_secrets.sh`
3. Build and start:
   - `make up`
4. Open:
   - `https://sdemiroz.42.fr` (browser will warn because the certificate is self-signed)
   - Admin panel: `https://sdemiroz.42.fr/wp-admin`

For a step-by-step implementation walkthrough (what to build first and why), see:
- `IMPLEMENTATION_GUIDE.md`

## Resources
- Docker Compose documentation
- NGINX documentation (TLS, reverse proxy, FastCGI)
- WordPress + php-fpm documentation
- MariaDB documentation

**AI usage:** Used to speed up drafting shell entrypoints, Docker/Compose structure, and to
generate checklists aligned with the subject; all scripts/configs were reviewed and
adapted to match 42 requirements (no infinite loops, correct PID 1 behavior, secrets).

## Comparisons (required)
- **Virtual Machines vs Docker**: VMs virtualize hardware + full OS; Docker virtualizes at the OS level and runs isolated processes sharing the host kernel, typically with less overhead.
- **Secrets vs Environment Variables**: env vars are convenient but can leak via logs/process inspection; Docker secrets mount sensitive values as files with tighter scope.
- **Docker Network vs Host Network**: a user-defined bridge network isolates services and provides DNS/service discovery; host networking removes isolation and is forbidden by the subject.
- **Docker Volumes vs Bind Mounts**: volumes are managed by Docker; bind mounts map a host path. This project uses Docker volumes configured to bind to `/home/<login>/data` to match the subject’s persistence requirement.
