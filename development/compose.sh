#!/usr/bin/env bash
set -euo pipefail

USER_ID=$(id -u "${USER}")
export USER_ID

GROUP_ID=$(id -g "${USER}")
export GROUP_ID

docker compose "$@"
