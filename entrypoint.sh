#!/bin/bash
set -euo pipefail

# Resolve server directory (Pterodactyl-safe)
if [ -d "/mnt/server" ]; then
  SERVER_DIR="/mnt/server"
elif [ -d "/home/container" ]; then
  SERVER_DIR="/home/container"
else
  echo "!! ERROR: Cannot locate server directory"
  exit 1
fi

SCHEMA_FILE="$SERVER_DIR/schema.sql"

cd "$SERVER_DIR"

echo ">> Server directory: $SERVER_DIR"

# ---- Database availability check ----
echo ">> Checking database connectivity..."

if ! mysqladmin ping \
  -h "${MYSQL_HOST}" \
  -P "${MYSQL_PORT}" \
  -u "${MYSQL_USER}" \
  -p"${MYSQL_PASSWORD}" \
  --silent; then

  echo ">> Database not reachable yet — skipping schema check."
  echo ">> Starting TFS without database."
  exec /usr/local/bin/tfs
fi

echo ">> Database reachable."

# ---- Schema check ----
TABLE_COUNT=$(mysql \
  -h "${MYSQL_HOST}" \
  -P "${MYSQL_PORT}" \
  -u "${MYSQL_USER}" \
  -p"${MYSQL_PASSWORD}" \
  -D "${MYSQL_DATABASE}" \
  -sN -e "SHOW TABLES;" | wc -l)

if [ "$TABLE_COUNT" -eq 0 ]; then
  echo ">> Database empty."

  if [ ! -f "$SCHEMA_FILE" ]; then
    echo "!! ERROR: schema.sql not found at $SCHEMA_FILE"
    exit 1
  fi

  echo ">> Importing schema.sql..."
  mysql \
    -h "${MYSQL_HOST}" \
    -P "${MYSQL_PORT}" \
    -u "${MYSQL_USER}" \
    -p"${MYSQL_PASSWORD}" \
    "${MYSQL_DATABASE}" < "$SCHEMA_FILE"

  echo ">> Schema imported."
else
  echo ">> Database already initialized ($TABLE_COUNT tables)."
fi

echo ">> Starting TFS..."
exec /usr/local/bin/tfs
