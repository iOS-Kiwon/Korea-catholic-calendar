#!/usr/bin/env bash
set -euo pipefail

export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
COMPOSE_FILE="$ROOT_DIR/ops/docker-compose.yml"
ENV_FILE="$ROOT_DIR/ops/.env"
env_value() {
  local key="$1"
  if [ -f "$ENV_FILE" ]; then
    sed -n "s/^${key}=//p" "$ENV_FILE" | tail -n 1
  fi
}

api_port() {
  local value
  value="${API_PORT:-$(env_value API_PORT)}"
  printf "%s\n" "${value:-8080}"
}

host_api_port() {
  local value
  value="${HOST_API_PORT:-$(env_value HOST_API_PORT)}"
  if [ -z "$value" ]; then
    value="$(api_port)"
  fi
  printf "%s\n" "$value"
}

die() {
  printf "[server] ERROR: %s\n" "$*" >&2
  exit 1
}

info() {
  printf "[server] %s\n" "$*"
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || die "$1 command not found"
}

require_env_file() {
  if [ ! -f "$ENV_FILE" ]; then
    die "ops/.env not found. Copy ops/.env.example to ops/.env and edit it first."
  fi
}

compose() {
  docker compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" "$@"
}

wait_for_docker() {
  require_command docker
  for i in $(seq 1 60); do
    if docker info >/dev/null 2>&1; then
      return 0
    fi
    info "Waiting for Docker... $i/60"
    sleep 2
  done
  die "Docker is not ready"
}

wait_for_health() {
  require_command curl
  local health_url
  health_url="http://127.0.0.1:$(host_api_port)/kcc/v1/health"
  for i in $(seq 1 30); do
    if curl -fsS "$health_url" >/dev/null 2>&1; then
      info "API health check passed: $health_url"
      return 0
    fi
    info "Waiting for API health... $i/30"
    sleep 2
  done
  die "API health check failed: $health_url"
}
