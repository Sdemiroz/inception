#!/usr/bin/env bash
set -euo pipefail

data_dir="/var/lib/mysql"
run_dir="/run/mysqld"
socket="${run_dir}/mysqld.sock"

sql_escape() {
  printf '%s' "$1" | sed "s/\\\\/\\\\\\\\/g; s/'/''/g"
}

if [[ -z "${MYSQL_DATABASE:-}" || -z "${MYSQL_USER:-}" ]]; then
  echo "Missing required env: MYSQL_DATABASE and/or MYSQL_USER" >&2
  exit 1
fi

if [[ ! "${MYSQL_DATABASE}" =~ ^[a-zA-Z0-9_]+$ ]]; then
  echo "Invalid MYSQL_DATABASE (allowed: letters, digits, underscore)." >&2
  exit 1
fi

if [[ ! "${MYSQL_USER}" =~ ^[a-zA-Z0-9_]+$ ]]; then
  echo "Invalid MYSQL_USER (allowed: letters, digits, underscore)." >&2
  exit 1
fi

if [[ -z "${MYSQL_PASSWORD_FILE:-}" || -z "${MYSQL_ROOT_PASSWORD_FILE:-}" ]]; then
  echo "Missing required env: MYSQL_PASSWORD_FILE and/or MYSQL_ROOT_PASSWORD_FILE" >&2
  exit 1
fi

if [[ ! -f "${MYSQL_PASSWORD_FILE}" || ! -f "${MYSQL_ROOT_PASSWORD_FILE}" ]]; then
  echo "Missing secrets files referenced by *_PASSWORD_FILE" >&2
  exit 1
fi

db_password="$(<"${MYSQL_PASSWORD_FILE}")"
root_password="$(<"${MYSQL_ROOT_PASSWORD_FILE}")"

mkdir -p "${data_dir}"
mysql_uid="$(id -u mysql)"
if [[ "$(stat -c %u "${data_dir}")" != "${mysql_uid}" ]]; then
  chown -R mysql:mysql "${data_dir}"
fi

mkdir -p "${run_dir}"
chown -R mysql:mysql "${run_dir}"

if [[ ! -d "${data_dir}/mysql" ]]; then
  mariadb-install-db --user=mysql --datadir="${data_dir}" > /dev/null
fi

sed -i 's/^[#[:space:]]*bind-address[[:space:]]*=.*/bind-address = 0.0.0.0/' /etc/mysql/mariadb.conf.d/50-server.cnf

if [[ ! -f "${data_dir}/.inception_initialized" ]]; then
  db_password_sql="$(sql_escape "${db_password}")"
  root_password_sql="$(sql_escape "${root_password}")"

  mysqld --user=mysql --datadir="${data_dir}" --skip-networking --skip-grant-tables --socket="${socket}" &
  temp_pid="$!"

  for _ in {1..60}; do
    if mariadb-admin --protocol=socket --socket="${socket}" ping > /dev/null 2>&1; then
      break
    fi
    sleep 1
  done

  mariadb --protocol=socket --socket="${socket}" -uroot <<-SQL
    FLUSH PRIVILEGES;
    ALTER USER 'root'@'localhost' IDENTIFIED BY '${root_password_sql}';
    CREATE DATABASE IF NOT EXISTS \`${MYSQL_DATABASE}\`;
    CREATE USER IF NOT EXISTS '${MYSQL_USER}'@'%' IDENTIFIED BY '${db_password_sql}';
    GRANT ALL PRIVILEGES ON \`${MYSQL_DATABASE}\`.* TO '${MYSQL_USER}'@'%';
    FLUSH PRIVILEGES;
SQL

  MYSQL_PWD="${root_password}" mariadb-admin \
  --protocol=socket \
  --socket="${socket}" \
  -uroot shutdown
  wait "${temp_pid}"

  touch "${data_dir}/.inception_initialized"
  chown mysql:mysql "${data_dir}/.inception_initialized"
fi

exec mysqld --user=mysql --datadir="${data_dir}" --socket="${socket}"
