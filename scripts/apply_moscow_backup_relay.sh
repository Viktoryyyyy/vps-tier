#!/usr/bin/env bash
set -Eeuo pipefail

EXPECTED_HOST_IPV4="147.45.184.140"
UPSTREAM_IPV4="194.32.142.88"
UPSTREAM_PORT="443"
LISTEN_PORT="8443"
SOCKET_UNIT="vps-backup-relay.socket"
SERVICE_UNIT="vps-backup-relay.service"
SOURCE_ROOT="hosts/moscow/etc/systemd/system"
TARGET_ROOT="/etc/systemd/system"
PROXYD="/usr/lib/systemd/systemd-socket-proxyd"
BACKUP_ROOT="/var/backups/vps-tier/moscow-backup-relay/apply"

MUTATION_STARTED=0
BACKUP_DIR=""
SOCKET_ACTIVE_BEFORE="inactive"
SOCKET_ENABLED_BEFORE="disabled"

die() {
  echo "ERROR: $*" >&2
  return 1
}

ok() {
  echo "OK: $*"
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "missing command: $1"
}

require_file() {
  [ -f "$1" ] || die "missing file: $1"
}

require_root() {
  [ "${EUID:-$(id -u)}" -eq 0 ] || die "run as root"
}

require_repo_root() {
  repo_root="$(git -c safe.directory="$PWD" rev-parse --show-toplevel 2>/dev/null)" || die "not inside a Git repository"
  [ "$repo_root" = "$PWD" ] || die "run from repository root: $repo_root"
}

host_has_expected_ipv4() {
  ip -4 -o addr show scope global | awk '{print $4}' | cut -d/ -f1 | grep -Fxq "$EXPECTED_HOST_IPV4"
}

port_has_listener() {
  ss -H -lnt "sport = :$1" | grep -q .
}

backup_one() {
  live_path="$1"
  backup_path="$BACKUP_DIR/${live_path#/}"
  mkdir -p "$(dirname "$backup_path")"
  if [ -e "$live_path" ]; then
    cp -a "$live_path" "$backup_path"
    printf 'file\t%s\t%s\tpresent\n' "$live_path" "$backup_path" >> "$BACKUP_DIR/MANIFEST.tsv"
  else
    printf 'file\t%s\t%s\tabsent\n' "$live_path" "$backup_path" >> "$BACKUP_DIR/MANIFEST.tsv"
  fi
}

restore_one() {
  live_path="$1"
  backup_path="$2"
  prior_state="$3"
  if [ "$prior_state" = "present" ]; then
    cp -a "$backup_path" "$live_path"
  else
    rm -f "$live_path"
  fi
}

rollback_on_error() {
  rc=$?
  trap - ERR
  if [ "$MUTATION_STARTED" -eq 1 ] && [ -n "$BACKUP_DIR" ] && [ -f "$BACKUP_DIR/MANIFEST.tsv" ]; then
    echo "ERROR: apply failed; restoring pre-apply relay state" >&2
    systemctl stop "$SERVICE_UNIT" "$SOCKET_UNIT" >/dev/null 2>&1 || true
    systemctl disable "$SOCKET_UNIT" >/dev/null 2>&1 || true
    while IFS=$'\t' read -r kind live_path backup_path prior_state; do
      [ "$kind" = "file" ] || continue
      restore_one "$live_path" "$backup_path" "$prior_state"
    done < "$BACKUP_DIR/MANIFEST.tsv"
    systemctl daemon-reload >/dev/null 2>&1 || true
    [ "$SOCKET_ENABLED_BEFORE" = "enabled" ] && systemctl enable "$SOCKET_UNIT" >/dev/null 2>&1 || true
    [ "$SOCKET_ACTIVE_BEFORE" = "active" ] && systemctl start "$SOCKET_UNIT" >/dev/null 2>&1 || true
  fi
  exit "$rc"
}

atomic_install() {
  src="$1"
  target="$2"
  tmp="$(mktemp "$TARGET_ROOT/.${target##*/}.relay.XXXXXX")"
  cp -f "$src" "$tmp"
  chown root:root "$tmp"
  chmod 0644 "$tmp"
  mv -f "$tmp" "$target"
}

require_root
require_cmd git
require_cmd ip
require_cmd ss
require_cmd awk
require_cmd grep
require_cmd timeout
require_cmd systemctl
require_cmd systemd-analyze
require_cmd nginx
require_cmd mktemp
require_repo_root

SOCKET_SOURCE="$SOURCE_ROOT/$SOCKET_UNIT"
SERVICE_SOURCE="$SOURCE_ROOT/$SERVICE_UNIT"
SOCKET_TARGET="$TARGET_ROOT/$SOCKET_UNIT"
SERVICE_TARGET="$TARGET_ROOT/$SERVICE_UNIT"

require_file "$SOCKET_SOURCE"
require_file "$SERVICE_SOURCE"
[ -x "$PROXYD" ] || die "missing executable: $PROXYD"
host_has_expected_ipv4 || die "host identity mismatch; expected IPv4 $EXPECTED_HOST_IPV4"

systemctl is-active --quiet nginx || die "nginx must be active before relay apply"
nginx -t >/dev/null 2>&1 || die "nginx validation failed before relay apply"
port_has_listener 443 || die "tcp/443 must already be listening before relay apply"
NGINX_PID_BEFORE="$(systemctl show -p MainPID --value nginx)"
[ -n "$NGINX_PID_BEFORE" ] && [ "$NGINX_PID_BEFORE" != "0" ] || die "unable to capture nginx MainPID"

if port_has_listener "$LISTEN_PORT" && ! systemctl is-active --quiet "$SOCKET_UNIT"; then
  die "tcp/$LISTEN_PORT is already owned by another service"
fi

if command -v ufw >/dev/null 2>&1 && ufw status 2>/dev/null | grep -q '^Status: active'; then
  ufw status 2>/dev/null | grep -Eq '(^|[[:space:]])8443(/tcp)?([[:space:]]|$).*ALLOW' || die "UFW is active but an ALLOW rule for tcp/8443 is not proven"
fi

timeout 5 bash -c "exec 3<>/dev/tcp/$UPSTREAM_IPV4/$UPSTREAM_PORT" || die "upstream $UPSTREAM_IPV4:$UPSTREAM_PORT is unreachable"
systemd-analyze verify "$SOCKET_SOURCE" "$SERVICE_SOURCE" >/dev/null
ok "preflight passed"

SOCKET_ACTIVE_BEFORE="$(systemctl is-active "$SOCKET_UNIT" 2>/dev/null || true)"
SOCKET_ENABLED_BEFORE="$(systemctl is-enabled "$SOCKET_UNIT" 2>/dev/null || true)"
BACKUP_ID="$(date -u +%Y%m%dT%H%M%SZ)"
BACKUP_DIR="$BACKUP_ROOT/$BACKUP_ID"
mkdir -p "$BACKUP_DIR"
chmod 0700 "$BACKUP_DIR"
printf 'created_by\tscripts/apply_moscow_backup_relay.sh\ncreated_at_utc\t%s\nsocket_active_before\t%s\nsocket_enabled_before\t%s\n' \
  "$BACKUP_ID" "$SOCKET_ACTIVE_BEFORE" "$SOCKET_ENABLED_BEFORE" > "$BACKUP_DIR/MANIFEST.tsv"
backup_one "$SOCKET_TARGET"
backup_one "$SERVICE_TARGET"

trap rollback_on_error ERR
MUTATION_STARTED=1
atomic_install "$SOCKET_SOURCE" "$SOCKET_TARGET"
atomic_install "$SERVICE_SOURCE" "$SERVICE_TARGET"
systemctl daemon-reload
systemctl enable --now "$SOCKET_UNIT" >/dev/null
sleep 1
systemctl is-active --quiet "$SOCKET_UNIT" || die "$SOCKET_UNIT is not active"
systemctl is-enabled --quiet "$SOCKET_UNIT" || die "$SOCKET_UNIT is not enabled"
port_has_listener "$LISTEN_PORT" || die "tcp/$LISTEN_PORT is not listening after apply"
timeout 5 bash -c "exec 3<>/dev/tcp/127.0.0.1/$LISTEN_PORT" || die "local relay activation test failed"
sleep 1
systemctl is-active --quiet "$SERVICE_UNIT" || die "$SERVICE_UNIT did not activate"

systemctl is-active --quiet nginx || die "nginx is not active after relay apply"
nginx -t >/dev/null 2>&1 || die "nginx validation failed after relay apply"
port_has_listener 443 || die "tcp/443 is not listening after relay apply"
NGINX_PID_AFTER="$(systemctl show -p MainPID --value nginx)"
[ "$NGINX_PID_AFTER" = "$NGINX_PID_BEFORE" ] || die "nginx MainPID changed during relay apply"

EVIDENCE_DIR="docs/observed/analysis"
EVIDENCE_FILE="$EVIDENCE_DIR/moscow_backup_relay_apply_$(date -u +%F).md"
mkdir -p "$EVIDENCE_DIR"
HEAD_SHA="$(git -c safe.directory="$PWD" rev-parse HEAD)"
cat > "$EVIDENCE_FILE" <<EOF
# Moscow Backup VLESS Relay — Apply Evidence

- UTC: $(date -u +%Y-%m-%dT%H:%M:%SZ)
- Git HEAD: $HEAD_SHA
- Host IPv4: $EXPECTED_HOST_IPV4
- Listener: tcp/$LISTEN_PORT
- Upstream: $UPSTREAM_IPV4:$UPSTREAM_PORT
- Socket active: yes
- Socket enabled: yes
- Proxy service activation: passed
- Upstream TCP reachable: yes
- Local activation test: passed
- Nginx active before/after: yes
- Nginx configuration before/after: valid
- Nginx MainPID unchanged: yes
- Nginx or Flowise configuration changed: no
- Kazakhstan server configuration changed: no
- Backup set: $BACKUP_DIR
EOF

trap - ERR
MUTATION_STARTED=0
ok "relay apply completed"
echo "EVIDENCE_FILE=$EVIDENCE_FILE"
echo "BACKUP_SET=$BACKUP_DIR"
echo "DONE"
