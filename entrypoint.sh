#!/bin/bash
set -euo pipefail

SERVER_DIR="/home/container"

cd "$SERVER_DIR"
echo ">> Server directory: $SERVER_DIR"

# ---- Ensure directories ----
mkdir -p www cache config

# ---- Render nginx port ----
sed -i "s/{{WEB_PORT}}/${WEB_PORT}/g" /etc/nginx/conf.d/default.conf

# ---- Start PHP-FPM (foreground-compatible) ----
echo ">> Starting PHP-FPM..."
php-fpm8.3 -D

# ---- Start nginx ----
echo ">> Starting nginx..."
nginx

# ---- Database bootstrap ----
echo ">> Checking database connectivity..."

if mysqladmin ping \
  -h "${MYSQL_HOST}" \
  -P "${MYSQL_PORT}" \
  -u "${MYSQL_USER}" \
  -p"${MYSQL_PASSWORD}" \
  --silent; then

  TABLE_COUNT=$(mysql \
    -h "${MYSQL_HOST}" \
    -P "${MYSQL_PORT}" \
    -u "${MYSQL_USER}" \
    -p"${MYSQL_PASSWORD}" \
    -D "${MYSQL_DATABASE}" \
    -sN -e "SHOW TABLES;" | wc -l)

  if [ "$TABLE_COUNT" -eq 0 ] && [ -f schema.sql ]; then
    echo ">> Importing schema.sql..."
    mysql \
      -h "${MYSQL_HOST}" \
      -P "${MYSQL_PORT}" \
      -u "${MYSQL_USER}" \
      -p"${MYSQL_PASSWORD}" \
      "${MYSQL_DATABASE}" < schema.sql
  fi
else
  echo ">> Database not reachable — skipping schema import."
fi

# ---- Signal handling ----
trap 'echo ">> Shutting down..."; nginx -s quit; pkill php-fpm; exit 0' SIGTERM SIGINT
if [ ! -f key.pem ]; then
  openssl genpkey -algorithm RSA -out key.pem -pkeyopt rsa_keygen_bits:2048
  chmod 600 key.pem
fi

# ---- Start TFS (PID 1) ----
echo ">> Starting TFS..."
exec /usr/local/bin/tfs
