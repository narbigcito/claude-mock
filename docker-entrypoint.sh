#!/bin/sh
set -eu

# Wait for the database to accept TCP connections before running migrations.
if [ -n "${DATABASE_URL:-}" ]; then
  echo "[entrypoint] running migrations"
  /app/bin/migrate
fi

if [ "${SEED_ON_BOOT:-false}" = "true" ]; then
  echo "[entrypoint] seeding conversations from priv/conversations/"
  /app/bin/seed
fi

exec "$@"
