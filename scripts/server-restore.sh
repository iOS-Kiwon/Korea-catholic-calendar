#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "$0")" && pwd)/server-common.sh"

usage() {
  cat <<'USAGE'
Usage:
  ./scripts/server-restore.sh PATH_TO_BACKUP.sql.gz --yes
  ./scripts/server-restore.sh PATH_TO_BACKUP.sql --yes

This drops and recreates the configured PostgreSQL database, then restores the backup.
USAGE
}

BACKUP_FILE="${1:-}"
CONFIRM="${2:-}"

if [ -z "$BACKUP_FILE" ] || [ "$CONFIRM" != "--yes" ]; then
  usage
  exit 1
fi

if [ ! -f "$BACKUP_FILE" ]; then
  die "Backup file not found: $BACKUP_FILE"
fi

require_env_file
wait_for_docker

set -a
source "$ENV_FILE"
set +a

require_command docker

info "Restoring PostgreSQL database from: $BACKUP_FILE"
info "Target database: $POSTGRES_DB"

compose up -d db

info "Terminating existing database connections"
compose exec -T db psql -U "$POSTGRES_USER" -d postgres -v ON_ERROR_STOP=1 \
  -c "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = '$POSTGRES_DB' AND pid <> pg_backend_pid();"

info "Dropping and recreating database"
compose exec -T db psql -U "$POSTGRES_USER" -d postgres -v ON_ERROR_STOP=1 \
  -c "DROP DATABASE IF EXISTS \"$POSTGRES_DB\";"
compose exec -T db psql -U "$POSTGRES_USER" -d postgres -v ON_ERROR_STOP=1 \
  -c "CREATE DATABASE \"$POSTGRES_DB\";"

info "Importing backup"
case "$BACKUP_FILE" in
  *.gz)
    gzip -dc "$BACKUP_FILE" | compose exec -T db psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -v ON_ERROR_STOP=1
    ;;
  *)
    compose exec -T db psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -v ON_ERROR_STOP=1 < "$BACKUP_FILE"
    ;;
esac

info "Restore complete"
info "Restarting services"
compose up -d --build
wait_for_health
