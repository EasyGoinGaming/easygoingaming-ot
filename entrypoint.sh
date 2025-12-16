#!/bin/bash
set -euo pipefail

SERVER_DIR="/mnt/server"
SCHEMA_FILE="$SERVER_DIR/schema.sql"

cd "$SERVER_DIR"

echo ">> Checking database state..."

TABLE_COUNT=$(mysql \
  -h "${MYSQL_HOST}" \
  -P "${MYSQL_PORT}" \
  -u "${MYSQL_USER}" \
  -p"${MYSQL_PASSWORD}" \
  -D "${MYSQL_DATABASE}" \
  -sN -e "SHOW TABLES;" | wc -l || true)

if [ "$TABLE_COUNT" -eq 0 ]; then
  echo ">> Database empty, importing schema.sql..."

  if [ ! -f "$SCHEMA_FILE" ]; then
    echo "!! ERROR: schema.sql not found at $SCHEMA_FILE"
    exit 1
  fi

  mysql \
    -h "${MYSQL_HOST}" \
    -P "${MYSQL_PORT}" \
    -u "${MYSQL_USER}" \
    -p"${MYSQL_PASSWORD}" \
    "${MYSQL_DATABASE}" < "$SCHEMA_FILE"

  echo ">> Database schema imported."
else
  echo ">> Database already initialized ($TABLE_COUNT tables found)."
fi

echo ">> Starting TFS..."
exec /usr/local/bin/tfs
