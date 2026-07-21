#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "$0")" && pwd)/server-common.sh"

require_env_file
wait_for_docker

SERVICE="${1:-}"
if [ -n "$SERVICE" ]; then
  compose logs -f --tail=200 "$SERVICE"
else
  compose logs -f --tail=200
fi
