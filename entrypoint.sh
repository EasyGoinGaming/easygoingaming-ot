#!/bin/bash
set -e

cd /mnt/server

echo ">> Checking database state..."

if mysql \
  -h "${MYSQL_HOST}" \
  -P "${MYSQL_PORT}" \
  -u "${MYSQL_USER}" \
  -p"${MYSQL_PASSWORD}" \
  "${MYSQL_DATABASE}" \
  -e "SHOW TABLES;" 2>/dev/null | grep -q .; then
    echo ">> Database already initialized."
else
    echo ">> Database empty, importing schema.sql..."
    mysql \
      -h "${MYSQL_HOST}" \
      -P "${MYSQL_PORT}" \
      -u "${MYSQL_USER}" \
      -p"${MYSQL_PASSWORD}" \
      "${MYSQL_DATABASE}" < schema.sql
    echo ">> Schema import complete."
fi

echo ">> Starting The Forgotten Server"
exec tfs
