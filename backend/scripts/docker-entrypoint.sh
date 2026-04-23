#!/bin/sh
set -eu

if [ "${TATUZIN_PERSISTENCE:-memory}" = "prisma" ]; then
  echo "[Tatuzin] Preparing Prisma persistence..."
  npx prisma generate

  if [ -d "/app/prisma/migrations" ] && [ "$(find /app/prisma/migrations -mindepth 1 -maxdepth 1 -type d 2>/dev/null)" ]; then
    echo "[Tatuzin] Applying Prisma migrations..."
    npx prisma migrate deploy
  else
    echo "[Tatuzin] No migrations found, syncing schema with prisma db push..."
    npx prisma db push --skip-generate
  fi
fi

exec "$@"
