#!/bin/bash
set -euo pipefail

SERVER_DIR="/home/container"
PHP_FPM_BIN="$(command -v php-fpm8.3 || command -v php-fpm8.2)"

cd "$SERVER_DIR"

echo ">> Server directory: $SERVER_DIR"

# ---- Start PHP-FPM ----
echo ">> Starting PHP-FPM..."
$PHP_FPM_BIN --daemonize

# ---- Configure nginx ----
echo ">> Configuring nginx..."
sed "s/{{WEB_PORT}}/${WEB_PORT}/g" nginx/default.conf > /tmp/nginx.conf
nginx -c /tmp/nginx.conf

# ---- Database bootstrap (same as before) ----
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

# ---- Start TFS ----
echo ">> Starting TFS..."
exec /usr/local/bin/tfs
