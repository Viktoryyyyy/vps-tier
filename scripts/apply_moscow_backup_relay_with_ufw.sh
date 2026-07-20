#!/usr/bin/env bash
set -Eeuo pipefail

EXPECTED_HOST_IPV4="147.45.184.140"
LISTEN_PORT="8443"
STATE_DIR="/var/lib/vps-tier/moscow-backup-relay"
STATE_FILE="$STATE_DIR/ufw-8443.created"
RELAY_APPLY="scripts/apply_moscow_backup_relay.sh"

RULE_ADDED_THIS_RUN=0

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

ufw_has_8443_allow() {
  ufw status 2>/dev/null | grep -Eq '^8443/tcp[[:space:]]+ALLOW IN'
}

rollback_firewall_on_error() {
  rc=$?
  trap - ERR
  if [ "$RULE_ADDED_THIS_RUN" -eq 1 ]; then
    echo "ERROR: relay apply failed; removing UFW rule created by this run" >&2
    ufw --force delete allow 8443/tcp >/dev/null 2>&1 || true
    rm -f "$STATE_FILE"
  fi
  exit "$rc"
}

[ "${EUID:-$(id -u)}" -eq 0 ] || die "run as root"
require_cmd git
require_cmd ip
require_cmd awk
require_cmd grep
require_cmd ufw
require_cmd mktemp

repo_root="$(git -c safe.directory="$PWD" rev-parse --show-toplevel 2>/dev/null)" || die "not inside a Git repository"
[ "$repo_root" = "$PWD" ] || die "run from repository root: $repo_root"
[ -f "$RELAY_APPLY" ] || die "missing relay apply script: $RELAY_APPLY"
host_has_expected_ipv4 || die "host identity mismatch; expected IPv4 $EXPECTED_HOST_IPV4"

trap rollback_firewall_on_error ERR

if ufw_is_active; then
  if ufw_has_8443_rule; then
    [ -f "$STATE_FILE" ] || die "tcp/$LISTEN_PORT already has an unmanaged UFW rule"
    ufw_has_8443_allow || die "managed tcp/$LISTEN_PORT UFW allow rule is not active"
    echo "OK: managed UFW allow for tcp/$LISTEN_PORT already present"
  else
    mkdir -p "$STATE_DIR"
    chmod 0700 "$STATE_DIR"
    ufw allow 8443/tcp comment 'vps-backup-relay' >/dev/null
    RULE_ADDED_THIS_RUN=1
    ufw_has_8443_allow || die "failed to verify UFW allow for tcp/$LISTEN_PORT"
    tmp="$(mktemp "$STATE_DIR/.ufw-8443.created.XXXXXX")"
    printf 'created_at_utc=%s\nrule=allow 8443/tcp\nowner=vps-backup-relay\n' \
      "$(date -u +%Y-%m-%dT%H:%M:%SZ)" > "$tmp"
    chmod 0600 "$tmp"
    mv -f "$tmp" "$STATE_FILE"
    echo "OK: UFW allow added for tcp/$LISTEN_PORT"
  fi
else
  echo "OK: UFW inactive; no firewall mutation required"
fi

bash "$RELAY_APPLY"

trap - ERR
RULE_ADDED_THIS_RUN=0

echo "DONE: Moscow backup relay and firewall apply completed"
echo "FIREWALL_STATE=$([ -f "$STATE_FILE" ] && echo managed || echo unchanged)"
echo "LISTENER=tcp/$LISTEN_PORT"
