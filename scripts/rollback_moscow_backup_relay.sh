#!/usr/bin/env bash
set -euo pipefail

EXPECTED_HOST_IPV4="147.45.184.140"
SOCKET_UNIT="vps-backup-relay.socket"
BACKUP_ROOT="/var/backups/vps-tier/moscow-backup-relay/apply"

BACKUP_DIR="${1:-}"

die() {
  echo "ERROR: $*" >&2
  exit 1
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "missing command: $1"
}

host_has_expected_ipv4() {
  ip -4 -o addr show scope global | awk '{print $4}' | cut -d/ -f1 | grep -Fxq "$EXPECTED_HOST_IPV4"
}

restore_one() {
  live_path="$1"
  backup_path="$2"
  prior_state="$3"
  if [ "$prior_state" = "present" ]; then
    [ -e "$backup_path" ] || die "missing backup file: $backup_path"
    cp -a "$backup_path" "$live_path"
  else
    rm -f "$live_path"
  fi
}

[ "${EUID:-$(id -u)}" -eq 0 ] || die "run as root"
require_cmd git
require_cmd ip
require_cmd awk
require_cmd grep
require_cmd systemctl
require_cmd nginx

repo_root="$(git -c safe.directory="$PWD" rev-parse --show-toplevel 2>/dev/null)" || die "not inside a Git repository"
[ "$repo_root" = "$PWD" ] || die "run from repository root: $repo_root"
host_has_expected_ipv4 || die "host identity mismatch; expected IPv4 $EXPECTED_HOST_IPV4"

if [ -z "$BACKUP_DIR" ]; then
  BACKUP_DIR="$(find "$BACKUP_ROOT" -mindepth 1 -maxdepth 1 -type d -printf '%p\n' 2>/dev/null | sort | tail -n 1)"
fi
[ -n "$BACKUP_DIR" ] || die "no backup set found"
MANIFEST="$BACKUP_DIR/MANIFEST.tsv"
[ -f "$MANIFEST" ] || die "missing manifest: $MANIFEST"

SOCKET_ACTIVE_BEFORE="$(awk -F '\t' '$1=="socket_active_before" {print $2}' "$MANIFEST" | tail -n 1)"
SOCKET_ENABLED_BEFORE="$(awk -F '\t' '$1=="socket_enabled_before" {print $2}' "$MANIFEST" | tail -n 1)"

NGINX_PID_BEFORE="$(systemctl show -p MainPID --value nginx)"
systemctl is-active --quiet nginx || die "nginx must be active before relay rollback"
nginx -t >/dev/null 2>&1 || die "nginx validation failed before relay rollback"

systemctl disable --now "$SOCKET_UNIT" >/dev/null 2>&1 || true
while IFS=$'\t' read -r kind live_path backup_path prior_state; do
  [ "$kind" = "file" ] || continue
  restore_one "$live_path" "$backup_path" "$prior_state"
done < "$MANIFEST"
systemctl daemon-reload

[ "$SOCKET_ENABLED_BEFORE" = "enabled" ] && systemctl enable "$SOCKET_UNIT" >/dev/null 2>&1 || true
[ "$SOCKET_ACTIVE_BEFORE" = "active" ] && systemctl start "$SOCKET_UNIT" >/dev/null 2>&1 || true

systemctl is-active --quiet nginx || die "nginx is not active after relay rollback"
nginx -t >/dev/null 2>&1 || die "nginx validation failed after relay rollback"
NGINX_PID_AFTER="$(systemctl show -p MainPID --value nginx)"
[ "$NGINX_PID_AFTER" = "$NGINX_PID_BEFORE" ] || die "nginx MainPID changed during relay rollback"

EVIDENCE_DIR="docs/observed/analysis"
EVIDENCE_FILE="$EVIDENCE_DIR/moscow_backup_relay_rollback_$(date -u +%F).md"
mkdir -p "$EVIDENCE_DIR"
cat > "$EVIDENCE_FILE" <<EOF
# Moscow Backup VLESS Relay — Rollback Evidence

- UTC: $(date -u +%Y-%m-%dT%H:%M:%SZ)
- Host IPv4: $EXPECTED_HOST_IPV4
- Backup set restored: $BACKUP_DIR
- Prior socket active state restored: ${SOCKET_ACTIVE_BEFORE:-unknown}
- Prior socket enabled state restored: ${SOCKET_ENABLED_BEFORE:-unknown}
- Nginx active before/after: yes
- Nginx configuration before/after: valid
- Nginx MainPID unchanged: yes
EOF

echo "DONE: relay rollback completed"
echo "EVIDENCE_FILE=$EVIDENCE_FILE"
echo "BACKUP_SET=$BACKUP_DIR"
