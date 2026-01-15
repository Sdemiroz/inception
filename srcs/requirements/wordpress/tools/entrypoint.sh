#!/usr/bin/env bash
set -euo pipefail

db_pass="$(</run/secrets/db_password)"
admin_pass="$(</run/secrets/wp_admin_password)"
user_pass="$(</run/secrets/wp_user_password)"

db_name="${WORDPRESS_DB_NAME:?WORDPRESS_DB_NAME is required}"
db_user="${WORDPRESS_DB_USER:?WORDPRESS_DB_USER is required}"
db_host="${WORDPRESS_DB_HOST:?WORDPRESS_DB_HOST is required}"

wp_title="${WP_TITLE:-Inception}"
wp_url="${WP_URL:?WP_URL is required}"
wp_admin_user="${WP_ADMIN_USER:?WP_ADMIN_USER is required}"
wp_admin_email="${WP_ADMIN_EMAIL:?WP_ADMIN_EMAIL is required}"
wp_user="${WP_USER:?WP_USER is required}"
wp_user_email="${WP_USER_EMAIL:?WP_USER_EMAIL is required}"

shopt -s nocasematch
if [[ "${wp_admin_user}" == *admin* ]]; then
  echo "WP_ADMIN_USER must not contain 'admin' (case-insensitive)." >&2
  exit 1
fi
shopt -u nocasematch

echo "Waiting for MariaDB at ${db_host}..."
for _ in {1..60}; do
  if mariadb --protocol=tcp -h"${db_host}" -u"${db_user}" -p"${db_pass}" -e "SELECT 1" > /dev/null 2>&1; then
    break
  fi
  sleep 1
done

if ! mariadb --protocol=tcp -h"${db_host}" -u"${db_user}" -p"${db_pass}" -e "SELECT 1" > /dev/null 2>&1; then
  echo "MariaDB not reachable after 60s." >&2
  exit 1
fi

if [[ ! -f /var/www/html/wp-config.php ]]; then
  if [[ ! -d /var/www/html/wp-admin ]]; then
    wp core download --allow-root --path=/var/www/html
  fi

  wp config create --allow-root \
    --path=/var/www/html \
    --dbname="${db_name}" \
    --dbuser="${db_user}" \
    --dbpass="${db_pass}" \
    --dbhost="${db_host}" \
    --force

  wp core install --allow-root \
    --path=/var/www/html \
    --url="${wp_url}" \
    --title="${wp_title}" \
    --admin_user="${wp_admin_user}" \
    --admin_password="${admin_pass}" \
    --admin_email="${wp_admin_email}" \
    --skip-email

  wp user create --allow-root \
    --path=/var/www/html \
    "${wp_user}" "${wp_user_email}" \
    --user_pass="${user_pass}" \
    --role=editor
fi

chown -R www-data:www-data /var/www/html

exec /usr/sbin/php-fpm8.2 -F
