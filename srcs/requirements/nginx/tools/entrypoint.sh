#!/usr/bin/env bash
set -euo pipefail

domain="${DOMAIN_NAME:?DOMAIN_NAME is required}"

ssl_dir="/etc/nginx/ssl"
crt="${ssl_dir}/${domain}.crt"
key="${ssl_dir}/${domain}.key"

mkdir -p "${ssl_dir}"

if [[ ! -f "${crt}" || ! -f "${key}" ]]; then
  openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout "${key}" \
    -out "${crt}" \
    -subj "/C=DE/ST=BW/L=Heilbronn/O=42/CN=${domain}"
fi

escaped_domain="$(printf '%s' "${domain}" | sed 's/[\\/&]/\\\\&/g')"
sed "s/__DOMAIN_NAME__/${escaped_domain}/g" /etc/nginx/templates/default.conf.template > /etc/nginx/sites-available/default

exec nginx -g 'daemon off;'
