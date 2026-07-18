#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "$0")" && pwd)/server-common.sh"

require_env_file
wait_for_docker

compose ps
wait_for_health
df -h
