#!/usr/bin/env bash
set -Eeuo pipefail

EXPECTED_HOST_IPV4="147.45.184.140"
LISTEN_PORT="8443"
STATE_FILE="/var/lib/vps-tier/moscow-backup-relay/ufw-8443.created"
RELAY_ROLLBACK="scripts/rollback_moscow_backup_relay.sh"

die() {
  echo "ERROR: $*" >&2
  return 1
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "missing command: $1"
}

host_has_expected_ipv4() {
  ip -4 -o addr show scope global | awk '{print $4}' | cut -d/ -f1 | grep -Fxq "$EXPECTED_HOST_IPV4"
}

ufw_is_active() {
  ufw status 2>/dev/null | grep -q '^Status: active$'
}

ufw_has_8443_rule() {
  ufw status numbered 2>/dev/null | grep -Eq '8443/tcp'
}

[ "${EUID:-$(id -u)}" -eq 0 ] || die "run as root"
require_cmd git
require_cmd ip
require_cmd awk
require_cmd grep
require_cmd ufw

repo_root="$(git -c safe.directory="$PWD" rev-parse --show-toplevel 2>/dev/null)" || die "not inside a Git repository"
[ "$repo_root" = "$PWD" ] || die "run from repository root: $repo_root"
[ -f "$RELAY_ROLLBACK" ] || die "missing relay rollback script: $RELAY_ROLLBACK"
host_has_expected_ipv4 || die "host identity mismatch; expected IPv4 $EXPECTED_HOST_IPV4"

bash "$RELAY_ROLLBACK" "$@"

if [ -f "$STATE_FILE" ]; then
  if ufw_is_active && ufw_has_8443_rule; then
    ufw --force delete allow 8443/tcp >/dev/null
    ufw_has_8443_rule && die "tcp/$LISTEN_PORT UFW rule remains after rollback"
  fi
  rm -f "$STATE_FILE"
  echo "OK: managed UFW rule for tcp/$LISTEN_PORT removed"
else
  echo "OK: no managed UFW rule marker; firewall unchanged"
fi

echo "DONE: Moscow backup relay and firewall rollback completed"
