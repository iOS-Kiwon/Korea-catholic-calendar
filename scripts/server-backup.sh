#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "$0")" && pwd)/server-common.sh"

require_env_file
wait_for_docker

set -a
source "$ENV_FILE"
set +a

BACKUP_DIR="${BACKUP_DIR:-$ROOT_DIR/backups}"
mkdir -p "$BACKUP_DIR"

STAMP="$(date +%Y%m%d-%H%M%S)"
OUT="$BACKUP_DIR/db-$STAMP.sql"

info "Writing PostgreSQL backup: $OUT"
compose exec -T db pg_dump -U "$POSTGRES_USER" "$POSTGRES_DB" > "$OUT"
info "Backup complete"
