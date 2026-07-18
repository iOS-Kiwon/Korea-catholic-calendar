#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "$0")" && pwd)/server-common.sh"

require_env_file
wait_for_docker

info "Stopping self-hosted services"
compose down
