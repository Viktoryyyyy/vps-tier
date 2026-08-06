#!/usr/bin/env bash
set -Eeuo pipefail

REPO_ROOT="/home/trader/vps-backup-relay"
APPLY_SCRIPT="scripts/apply_moscow_awg_toolchain.sh"

[ "${EUID:-$(id -u)}" -eq 0 ] || {
  echo "ERROR: run as root" >&2
  exit 1
}

[ "$PWD" = "$REPO_ROOT" ] || {
  echo "ERROR: run from $REPO_ROOT" >&2
  exit 1
}

[ -f "$APPLY_SCRIPT" ] || {
  echo "ERROR: missing $APPLY_SCRIPT" >&2
  exit 1
}

export GIT_CONFIG_COUNT=1
export GIT_CONFIG_KEY_0=safe.directory
export GIT_CONFIG_VALUE_0="$REPO_ROOT"

exec /usr/bin/bash "$APPLY_SCRIPT"
