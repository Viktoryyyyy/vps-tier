#!/usr/bin/env bash
set -Eeuo pipefail

SOURCE_HEAD="${VPS_TIER_SOURCE_HEAD:-}"
EXPECTED_IPV4="194.32.142.88"
SYSCTL_FILE="/etc/sysctl.d/99-vps-tier-kz-client-egress.conf"
SYSCTL_TMP="${SYSCTL_FILE}.tmp"
STATE_DIR="/var/lib/vps-tier/kz-forwarding-persistence"
STATE_FILE="$STATE_DIR/state.env"
EVIDENCE_FILE="$STATE_DIR/evidence.md"
BACKUP_ROOT="/var/backups/vps-tier/kz-forwarding-persistence/apply"
FILE_CREATED=0
BACKUP_DIR=""

fail() { echo "ERROR: $*" >&2; return 1; }
host_ok() { ip -4 -o addr show scope global | awk '{print $4}' | cut -d/ -f1 | grep -Fx "$EXPECTED_IPV4" >/dev/null; }
persistent_assignments() {
  grep -RhsE '^[[:space:]]*(net\.ipv4\.ip_forward|net\.ipv6\.conf\.all\.forwarding)[[:space:]]*=' \
    /etc/sysctl.conf /etc/sysctl.d /run/sysctl.d /usr/local/lib/sysctl.d /usr/lib/sysctl.d /lib/sysctl.d 2>/dev/null || true
}
rollback_on_error() {
  rc=$?; trap - ERR; set +e
  echo "ERROR: forwarding persistence apply failed; reverting task-owned state" >&2
  [ "$FILE_CREATED" -eq 0 ] || rm -f "$SYSCTL_FILE"
  rm -f "$SYSCTL_TMP"
  [ -z "${IPV4_BEFORE:-}" ] || sysctl -q -w net.ipv4.ip_forward="$IPV4_BEFORE"
  [ -z "${IPV6_BEFORE:-}" ] || sysctl -q -w net.ipv6.conf.all.forwarding="$IPV6_BEFORE"
  rm -rf "$STATE_DIR"
  exit "$rc"
}

[ "${EUID:-$(id -u)}" -eq 0 ] || fail "run as root"
[[ "$SOURCE_HEAD" =~ ^[0-9a-f]{40}$ ]] || fail "VPS_TIER_SOURCE_HEAD must be a full lowercase commit SHA"
host_ok || fail "host identity mismatch"
[ ! -e "$STATE_DIR" ] || fail "managed forwarding-persistence state already exists"
[ ! -e "$SYSCTL_FILE" ] || fail "managed sysctl file already exists"
IPV4_BEFORE="$(sysctl -n net.ipv4.ip_forward)"
IPV6_BEFORE="$(sysctl -n net.ipv6.conf.all.forwarding)"
[ "$IPV4_BEFORE" = 1 ] || fail "IPv4 forwarding must already equal 1"
[ "$IPV6_BEFORE" = 0 ] || fail "IPv6 forwarding must already equal 0"
EXISTING="$(persistent_assignments)"
[ -z "$EXISTING" ] || { printf '%s\n' "$EXISTING" >&2; fail "pre-existing persistent forwarding assignment found"; }

BACKUP_ID="$(date -u +%Y%m%dT%H%M%SZ)"
BACKUP_DIR="$BACKUP_ROOT/$BACKUP_ID"
mkdir -p "$BACKUP_DIR" "$STATE_DIR"
chmod 0700 "$BACKUP_DIR" "$STATE_DIR"
printf '%s\n' "$EXISTING" > "$BACKUP_DIR/persistent-assignments.before"

cat > "$SYSCTL_TMP" <<'EOF'
# Managed by vps-tier: Kazakhstan client-egress Stage 4
net.ipv4.ip_forward = 1
net.ipv6.conf.all.forwarding = 0
EOF
chmod 0644 "$SYSCTL_TMP"
trap rollback_on_error ERR
mv "$SYSCTL_TMP" "$SYSCTL_FILE"; FILE_CREATED=1
sysctl -q -p "$SYSCTL_FILE"
[ "$(sysctl -n net.ipv4.ip_forward)" = 1 ] || fail "IPv4 forwarding validation failed"
[ "$(sysctl -n net.ipv6.conf.all.forwarding)" = 0 ] || fail "IPv6 forwarding validation failed"
FILE_SHA="$(sha256sum "$SYSCTL_FILE" | awk '{print $1}')"

cat > "$STATE_FILE" <<STATE
owner=vps-tier
source_head=$SOURCE_HEAD
applied_at_utc=$BACKUP_ID
backup_set=$BACKUP_DIR
sysctl_file=$SYSCTL_FILE
sysctl_file_sha256=$FILE_SHA
ipv4_before=$IPV4_BEFORE
ipv6_before=$IPV6_BEFORE
STATE
chmod 0600 "$STATE_FILE"
cat > "$EVIDENCE_FILE" <<EVIDENCE
# Kazakhstan Forwarding Persistence — Apply Evidence

- Source Git HEAD: $SOURCE_HEAD
- IPv4 forwarding runtime before/after: $IPV4_BEFORE/$(sysctl -n net.ipv4.ip_forward)
- IPv6 forwarding runtime before/after: $IPV6_BEFORE/$(sysctl -n net.ipv6.conf.all.forwarding)
- Persistent sysctl file: $SYSCTL_FILE
- Pre-existing persistent assignments: none
- Secrets recorded: no
EVIDENCE
chmod 0600 "$EVIDENCE_FILE"
trap - ERR
FILE_CREATED=0

echo "DONE: Kazakhstan forwarding persistence prepared"
echo "IPV4_FORWARD_PERSISTENT=1"
echo "IPV6_FORWARD_PERSISTENT=0"
echo "EVIDENCE_FILE=$EVIDENCE_FILE"