#!/usr/bin/env bash
set -Eeuo pipefail

EXPECTED_HOST_IPV4="147.45.184.140"
KEYRING="/usr/share/keyrings/vps-tier-amnezia-archive-keyring.gpg"
SOURCE_FILE="/etc/apt/sources.list.d/vps-tier-amnezia.sources"
STATE_DIR="/var/lib/vps-tier/moscow-awg-toolchain"
STATE_FILE="$STATE_DIR/state.env"
NEW_PACKAGES_FILE="$STATE_DIR/new-packages.txt"
PROTECTED_UNITS=(ssh.socket nginx.service postgresql.service flowise-proxy.service vps-backup-relay.socket)

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

package_installed() {
  dpkg-query -W -f='${Status}\n' "$1" 2>/dev/null | grep -qx 'install ok installed'
}

snapshot_firewall_routes() {
  {
    echo '--- UFW ---'
    ufw status numbered
    echo '--- IPV4 RULES ---'
    ip -4 rule show
    echo '--- IPV4 ROUTES ---'
    ip -4 route show table all
    echo '--- FORWARDING ---'
    sysctl -n net.ipv4.ip_forward
    sysctl -n net.ipv6.conf.all.forwarding
  } | sha256sum | awk '{print $1}'
}

assert_protected_units_active() {
  for unit in "${PROTECTED_UNITS[@]}"; do
    systemctl is-active --quiet "$unit" || die "protected unit is not active: $unit"
  done
}

[ "${EUID:-$(id -u)}" -eq 0 ] || die "run as root"
for cmd in git ip awk grep cut apt-get dpkg-query sha256sum xargs systemctl modprobe modinfo lsmod ufw sysctl; do
  require_cmd "$cmd"
done

repo_root="$(git -c safe.directory="$PWD" rev-parse --show-toplevel 2>/dev/null)" || die "not inside a Git repository"
[ "$repo_root" = "$PWD" ] || die "run from repository root: $repo_root"
[ "$(git branch --show-current)" = "main" ] || die "run from main branch"
[ -z "$(git status --porcelain)" ] || die "working tree must be clean"
host_has_expected_ipv4 || die "host identity mismatch; expected IPv4 $EXPECTED_HOST_IPV4"

[ -f "$STATE_FILE" ] || die "managed AWG toolchain state is absent"
[ -f "$NEW_PACKAGES_FILE" ] || die "managed new-package manifest is absent"
[ -f "$SOURCE_FILE" ] || die "managed APT source is absent"
[ -f "$KEYRING" ] || die "managed keyring is absent"

grep -qx 'owner=vps-tier' "$STATE_FILE" || die "state ownership mismatch"
BACKUP_SET="$(awk -F= '$1=="backup_set" {print substr($0,index($0,"=")+1)}' "$STATE_FILE" | tail -n 1)"
[ -n "$BACKUP_SET" ] || die "backup set missing from state"

ip -o link show | grep -Eiq '(^|: )[[:alnum:]_.-]*(awg|amnezia)' && \
  die "AWG interface exists; remove client-ingress configuration before toolchain rollback"

assert_protected_units_active
FIREWALL_ROUTE_HASH_BEFORE="$(snapshot_firewall_routes)"

modprobe -r amneziawg >/dev/null 2>&1 || true
lsmod | grep -q '^amneziawg ' && die "amneziawg module is still loaded"

if [ -s "$NEW_PACKAGES_FILE" ]; then
  xargs -r apt-get purge -y -- < "$NEW_PACKAGES_FILE"
fi

rm -f "$SOURCE_FILE" "$KEYRING"
apt-get update >/dev/null

package_installed amneziawg && die "amneziawg remains installed"
package_installed amneziawg-dkms && die "amneziawg-dkms remains installed"
command -v awg >/dev/null 2>&1 && die "awg command remains present"
command -v awg-quick >/dev/null 2>&1 && die "awg-quick command remains present"
modinfo amneziawg >/dev/null 2>&1 && die "amneziawg module metadata remains present"

assert_protected_units_active
FIREWALL_ROUTE_HASH_AFTER="$(snapshot_firewall_routes)"
[ "$FIREWALL_ROUTE_HASH_AFTER" = "$FIREWALL_ROUTE_HASH_BEFORE" ] || die "firewall or route state changed"

ROLLBACK_ID="$(date -u +%Y%m%dT%H%M%SZ)"
EVIDENCE_FILE="docs/observed/analysis/moscow_awg_toolchain_rollback_${ROLLBACK_ID}.md"
cat > "$EVIDENCE_FILE" <<EOF
# Moscow AmneziaWG Toolchain — Rollback Evidence

- UTC: $(date -u +%Y-%m-%dT%H:%M:%SZ)
- Git HEAD: $(git rev-parse HEAD)
- Host IPv4: $EXPECTED_HOST_IPV4
- Original backup set: $BACKUP_SET
- Task-owned packages removed: yes
- Managed APT source removed: yes
- Managed keyring removed: yes
- AWG commands absent: yes
- AWG module absent: yes
- AWG interface present before rollback: no
- Firewall, forwarding, and route state changed: no
- Protected units active before/after: yes
- Kazakhstan server changed: no
- Secrets recorded: no
EOF

rm -rf "$STATE_DIR"

echo "DONE: Moscow AWG toolchain rollback completed"
echo "EVIDENCE_FILE=$EVIDENCE_FILE"
echo "BACKUP_SET=$BACKUP_SET"
