#!/usr/bin/env bash
set -euo pipefail

# ================= CONFIG (FROM ENV) =================
PG_CONTAINER_NAME="${PG_CONTAINER_NAME:-postgres}"
PG_DB="${PG_DB:-postgres}"
PG_USER="${PG_USER:-postgres}"
PG_PASSWORD="${PG_PASSWORD}"

TELEGRAM_BOT_TOKEN="${TELEGRAM_BOT_TOKEN}"
TELEGRAM_CHAT_ID="${TELEGRAM_CHAT_ID}"

TIMEZONE="${TIMEZONE:-UTC}"

# ================= VALIDATION =================
for var in PG_PASSWORD TELEGRAM_BOT_TOKEN TELEGRAM_CHAT_ID; do
  if [ -z "${!var:-}" ]; then
    echo "❌ Environment variable $var is not set"
    exit 1
  fi
done

# ================= META =================
IP=$(hostname -I | awk '{print $1}')
TIMESTAMP=$(TZ="$TIMEZONE" date +%Y%m%d-%H%M)
WORKDIR="/tmp/remnawave_backup_$TIMESTAMP"
ARCHIVE="$WORKDIR/remnawave_backup.zip"

mkdir -p "$WORKDIR"

# ================= DB BACKUP =================
docker exec -e PGPASSWORD="$PG_PASSWORD" "$PG_CONTAINER_NAME" \
  pg_dump -U "$PG_USER" "$PG_DB" > "$WORKDIR/postgres.sql"

# ================= ARCHIVE =================
zip -9 -r "$ARCHIVE" \
  /opt/remnawave/docker-compose.yml \
  /opt/remnawave/subscription \
  /opt/remnawave/caddy

# ================= SEND TO TELEGRAM =================
curl -s \
  -F "chat_id=$TELEGRAM_CHAT_ID" \
  -F "document=@$ARCHIVE" \
  -F "caption=📦 Remnawave backup from $IP ($TIMESTAMP)" \
  "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/sendDocument"

# ================= CLEANUP =================
rm -rf "$WORKDIR"

echo "✅ Backup completed successfully"
