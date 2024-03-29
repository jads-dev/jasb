#!/usr/bin/env bash
set -euo pipefail

USER_ID=$(id -u "${USER}")
export USER_ID

GROUP_ID=$(id -g "${USER}")
export GROUP_ID

DEVELOPMENT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd -P)
docker compose -f "${DEVELOPMENT_DIR}/compose.yaml" "$@"
