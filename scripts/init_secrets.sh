#!/usr/bin/env bash
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
secrets_dir="${root_dir}/secrets"

mkdir -p "${secrets_dir}"

gen_secret() {
  if command -v openssl > /dev/null 2>&1; then
    openssl rand -base64 32 | tr -d '\n'
    return
  fi
  head -c 48 /dev/urandom | base64 | tr -d '\n'
}

write_if_missing() {
  local path="$1"
  if [[ -f "${path}" ]]; then
    return
  fi
  umask 077
  gen_secret > "${path}"
  printf '\n' >> "${path}"
}

write_if_missing "${secrets_dir}/db_root_password.txt"
write_if_missing "${secrets_dir}/db_password.txt"
write_if_missing "${secrets_dir}/wp_admin_password.txt"
write_if_missing "${secrets_dir}/wp_user_password.txt"

chmod 600 "${secrets_dir}"/*.txt || true

echo "Secrets are ready in: ${secrets_dir}"
echo "Edit `srcs/.env` to match your login/domain before running `make up`."
