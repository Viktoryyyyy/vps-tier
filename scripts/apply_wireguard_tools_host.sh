#!/usr/bin/env bash
set -Eeuo pipefail

ROLE="${1:-}"
SOURCE_HEAD="${VPS_TIER_SOURCE_HEAD:-}"
PACKAGE="wireguard-tools"
BACKBONE_ROUTE="10.70.0.0/30"

case "$ROLE" in
  moscow)
    EXPECTED_IPV4="147.45.184.140"
    EXPECTED_CODENAME="noble"
    ;;
  kazakhstan)
    EXPECTED_IPV4="194.32.142.88"
    EXPECTED_CODENAME="jammy"
    ;;
  *)
    echo "ERROR: role must be moscow or kazakhstan" >&2
    exit 1
    ;;
esac

STATE_DIR="/var/lib/vps-tier/wireguard-tools/$ROLE"
STATE_FILE="$STATE_DIR/state.env"
NEW_PACKAGES_FILE="$STATE_DIR/new-packages.txt"
EVIDENCE_FILE="$STATE_DIR/evidence.md"
BACKUP_ROOT="/var/backups/vps-tier/wireguard-tools/$ROLE/apply"
BACKUP_DIR=""
PKG_BEFORE=""
MUTATION_STARTED=0

fail() {
  echo "ERROR: $*" >&2
  return 1
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || fail "missing command: $1"
}

package_installed() {
  dpkg-query -W -f='${Status}\n' "$1" 2>/dev/null | grep -x 'install ok installed' >/dev/null
}

snapshot_packages() {
  dpkg-query -W -f='${binary:Package}\n' 2>/dev/null | sort -u
}

snapshot_network_state() {
  {
    ufw status numbered
    ip -4 rule show
    ip -4 route show table all
    sysctl -n net.ipv4.ip_forward
    sysctl -n net.ipv6.conf.all.forwarding
    ss -H -lunp 'sport = :51820'
  } | sha256sum | awk '{print $1}'
}

host_has_expected_ipv4() {
  ip -4 -o addr show scope global | awk '{print $4}' | cut -d/ -f1 | grep -Fx "$EXPECTED_IPV4" >/dev/null
}

rollback_on_error() {
  rc=$?
  trap - ERR
  echo "ERROR: WireGuard tools apply failed; reverting task-owned packages" >&2
  if [ "$MUTATION_STARTED" -eq 1 ] && [ -n "$PKG_BEFORE" ] && [ -f "$PKG_BEFORE" ]; then
    current_packages="$(mktemp)"
    new_packages="$(mktemp)"
    snapshot_packages > "$current_packages"
    comm -13 "$PKG_BEFORE" "$current_packages" > "$new_packages"
    if [ -s "$new_packages" ]; then
      xargs -r apt-get purge -y -- < "$new_packages" >/dev/null 2>&1 || true
    fi
    rm -f "$current_packages" "$new_packages"
  fi
  rm -rf "$STATE_DIR"
  exit "$rc"
}

[ "${EUID:-$(id -u)}" -eq 0 ] || fail "run as root"
[[ "$SOURCE_HEAD" =~ ^[0-9a-f]{40}$ ]] || fail "VPS_TIER_SOURCE_HEAD must be a full lowercase commit SHA"

for cmd in apt-cache apt-get awk comm cut dpkg-query grep ip mktemp sha256sum sort ss sysctl ufw xargs; do
  require_cmd "$cmd"
done

host_has_expected_ipv4 || fail "host identity mismatch; expected IPv4 $EXPECTED_IPV4"
. /etc/os-release
[ "${ID:-}" = "ubuntu" ] || fail "OS mismatch: ${ID:-unknown}"
[ "${VERSION_CODENAME:-}" = "$EXPECTED_CODENAME" ] || fail "suite mismatch: ${VERSION_CODENAME:-unknown}"
[ "$(dpkg --print-architecture)" = "amd64" ] || fail "architecture mismatch"

[ ! -e "$STATE_DIR" ] || fail "managed state already exists: $STATE_DIR"
package_installed "$PACKAGE" && fail "$PACKAGE is already installed outside this task"
command -v wg >/dev/null 2>&1 && fail "wg command already exists"
modinfo wireguard >/dev/null 2>&1 || fail "wireguard kernel module metadata is absent"
ip -o link show type wireguard 2>/dev/null | grep . >/dev/null && fail "WireGuard interface already exists"
ip -4 route show | grep -F "$BACKBONE_ROUTE" >/dev/null && fail "backbone route already exists"
ss -H -lunp 'sport = :51820' | grep . >/dev/null && fail "udp/51820 is occupied"

apt-cache policy "$PACKAGE" | grep -E "[[:space:]]${EXPECTED_CODENAME}/main[[:space:]]+amd64 Packages" >/dev/null || \
  fail "$PACKAGE candidate is not from Ubuntu ${EXPECTED_CODENAME}/main"
CANDIDATE="$(apt-cache policy "$PACKAGE" | awk '/^[[:space:]]*Candidate:/ {print $2; exit}')"
[ -n "$CANDIDATE" ] && [ "$CANDIDATE" != "(none)" ] || fail "no $PACKAGE candidate"

NETWORK_HASH_BEFORE="$(snapshot_network_state)"
BACKUP_ID="$(date -u +%Y%m%dT%H%M%SZ)"
BACKUP_DIR="$BACKUP_ROOT/$BACKUP_ID"
mkdir -p "$BACKUP_DIR" "$STATE_DIR"
chmod 0700 "$BACKUP_DIR" "$STATE_DIR"
PKG_BEFORE="$BACKUP_DIR/packages.before"
snapshot_packages > "$PKG_BEFORE"

trap rollback_on_error ERR
MUTATION_STARTED=1
DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends --no-upgrade "$PACKAGE"

package_installed "$PACKAGE" || fail "$PACKAGE is not installed"
command -v wg >/dev/null 2>&1 || fail "wg command missing after install"
command -v wg-quick >/dev/null 2>&1 || fail "wg-quick command missing after install"
modinfo wireguard >/dev/null 2>&1 || fail "wireguard module metadata missing after install"
ip -o link show type wireguard 2>/dev/null | grep . >/dev/null && fail "unexpected WireGuard interface created"
ip -4 route show | grep -F "$BACKBONE_ROUTE" >/dev/null && fail "unexpected backbone route created"
ss -H -lunp 'sport = :51820' | grep . >/dev/null && fail "udp/51820 became occupied"
NETWORK_HASH_AFTER="$(snapshot_network_state)"
[ "$NETWORK_HASH_AFTER" = "$NETWORK_HASH_BEFORE" ] || fail "firewall, forwarding, route, or listener state changed"

snapshot_packages > "$BACKUP_DIR/packages.after"
comm -13 "$PKG_BEFORE" "$BACKUP_DIR/packages.after" > "$NEW_PACKAGES_FILE"
chmod 0600 "$NEW_PACKAGES_FILE"
INSTALLED_VERSION="$(dpkg-query -W -f='${Version}' "$PACKAGE")"

cat > "$STATE_FILE" <<EOF
owner=vps-tier
role=$ROLE
source_head=$SOURCE_HEAD
applied_at_utc=$BACKUP_ID
backup_set=$BACKUP_DIR
package=$PACKAGE
version=$INSTALLED_VERSION
EOF
chmod 0600 "$STATE_FILE"

cat > "$EVIDENCE_FILE" <<EOF
# $ROLE WireGuard Tools — Apply Evidence

- UTC: $(date -u +%Y-%m-%dT%H:%M:%SZ)
- Source Git HEAD: $SOURCE_HEAD
- Host IPv4: $EXPECTED_IPV4
- OS: $ID $VERSION_ID $VERSION_CODENAME
- Kernel: $(uname -r)
- wireguard-tools candidate: $CANDIDATE
- wireguard-tools installed version: $INSTALLED_VERSION
- WireGuard kernel module metadata: present
- wg command: present
- wg-quick command: present
- WireGuard interface created: no
- Backbone route created: no
- UDP/51820 changed: no
- Firewall, forwarding, and route state changed: no
- Backup set: $BACKUP_DIR
- Secrets recorded: no
EOF
chmod 0600 "$EVIDENCE_FILE"

trap - ERR

echo "DONE: WireGuard tools installed and validated"
echo "ROLE=$ROLE"
echo "VERSION=$INSTALLED_VERSION"
echo "EVIDENCE_FILE=$EVIDENCE_FILE"
echo "BACKUP_SET=$BACKUP_DIR"
