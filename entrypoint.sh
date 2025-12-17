#!/bin/bash
set -euo pipefail

SERVER_DIR="/home/container"
NGINX_RENDERED_CONF="${SERVER_DIR}/nginx.conf"

cd "$SERVER_DIR"
echo ">> Server directory: $SERVER_DIR"

# ---- Ensure web directories ----
mkdir -p "${SERVER_DIR}/www"
mkdir -p "${SERVER_DIR}/www/cache" "${SERVER_DIR}/www/config"

# ---- Render nginx config into writable location ----
: "${WEB_PORT:=8080}"
echo ">> Rendering nginx config for WEB_PORT=${WEB_PORT}..."
sed "s/{{WEB_PORT}}/${WEB_PORT}/g" /etc/nginx/template.conf > "${NGINX_RENDERED_CONF}"

PHP_FPM_CONF="${SERVER_DIR}/php-fpm.conf"
PHP_FPM_SOCK="${SERVER_DIR}/php-fpm.sock"

cat > "${PHP_FPM_CONF}" <<EOF
[global]
error_log = /proc/self/fd/2
daemonize = yes
pid = ${SERVER_DIR}/php-fpm.pid

[www]
listen = ${PHP_FPM_SOCK}
listen.mode = 0660

pm = dynamic
pm.max_children = 5
pm.start_servers = 2
pm.min_spare_servers = 1
pm.max_spare_servers = 3

clear_env = no
EOF

echo ">> Starting PHP-FPM with custom config..."
php-fpm8.3 --fpm-config "${PHP_FPM_CONF}"
NGINX_DIR="/home/container/nginx"

mkdir -p \
  "$NGINX_DIR"/{tmp,logs,client_body,fastcgi,proxy,uwsgi,scgi}

# ---- Start nginx using rendered config ----
echo ">> Starting nginx..."
nginx -c "${NGINX_RENDERED_CONF}"

# ---- Ensure RSA key exists (TFS expects it next to config.lua) ----
if [ ! -f "${SERVER_DIR}/key.pem" ]; then
  echo ">> Generating RSA key..."
  openssl genpkey -algorithm RSA -out "${SERVER_DIR}/key.pem" -pkeyopt rsa_keygen_bits:2048
  chmod 600 "${SERVER_DIR}/key.pem"
fi

# ---- Optional schema import (only if DB reachable + empty + schema.sql exists) ----
echo ">> Checking database connectivity..."
if mysqladmin ping \
  -h "${MYSQL_HOST:-db}" \
  -P "${MYSQL_PORT:-3306}" \
  -u "${MYSQL_USER:-root}" \
  -p"${MYSQL_PASSWORD:-}" \
  --silent; then

  echo ">> Database reachable."

  TABLE_COUNT="$(mysql \
    -h "${MYSQL_HOST:-db}" \
    -P "${MYSQL_PORT:-3306}" \
    -u "${MYSQL_USER:-root}" \
    -p"${MYSQL_PASSWORD:-}" \
    -D "${MYSQL_DATABASE:-forgottenserver}" \
    -sN -e "SHOW TABLES;" | wc -l)"

  if [ "${TABLE_COUNT}" -eq 0 ] && [ -f "${SERVER_DIR}/schema.sql" ]; then
    echo ">> Database empty, importing schema.sql..."
    mysql \
      -h "${MYSQL_HOST:-db}" \
      -P "${MYSQL_PORT:-3306}" \
      -u "${MYSQL_USER:-root}" \
      -p"${MYSQL_PASSWORD:-}" \
      "${MYSQL_DATABASE:-forgottenserver}" < "${SERVER_DIR}/schema.sql"
    echo ">> Schema imported."
  else
    echo ">> Database already initialized (${TABLE_COUNT} tables) or schema.sql missing."
  fi
else
  echo ">> Database not reachable — skipping schema import."
fi

# ---- Signal handling (graceful) ----
term_handler() {
  echo ">> Shutting down..."
  nginx -s quit || true
  pkill php-fpm8.3 || true
  exit 0
}
trap term_handler SIGTERM SIGINT

# ---- Start TFS (PID 1) ----
echo ">> Starting TFS..."
exec /usr/local/bin/tfs
