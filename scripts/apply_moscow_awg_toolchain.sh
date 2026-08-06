#!/usr/bin/env bash
set -Eeuo pipefail

EXPECTED_HOST_IPV4="147.45.184.140"
EXPECTED_OS_ID="ubuntu"
EXPECTED_OS_CODENAME="noble"
EXPECTED_ARCH="amd64"
PPA_URI="https://ppa.launchpadcontent.net/amnezia/ppa/ubuntu"
SIGNING_KEY_FINGERPRINT="75C9DD72C799870E310542E24166F2C257290828"
KEY_URL="https://keyserver.ubuntu.com/pks/lookup?op=get&search=0x${SIGNING_KEY_FINGERPRINT}"
KEYRING="/usr/share/keyrings/vps-tier-amnezia-archive-keyring.gpg"
SOURCE_FILE="/etc/apt/sources.list.d/vps-tier-amnezia.sources"
STATE_DIR="/var/lib/vps-tier/moscow-awg-toolchain"
STATE_FILE="$STATE_DIR/state.env"
NEW_PACKAGES_FILE="$STATE_DIR/new-packages.txt"
BACKUP_ROOT="/var/backups/vps-tier/moscow-awg-toolchain/apply"
PROBE_SCRIPT="scripts/probe_moscow_awg_package_source.sh"
PACKAGES=(dkms amneziawg amneziawg-dkms)
PROTECTED_UNITS=(ssh.socket nginx.service postgresql.service flowise-proxy.service vps-backup-relay.socket)

TMP_ROOT=""
BACKUP_DIR=""
PKG_BEFORE=""
MUTATION_STARTED=0

cleanup_tmp() {
  if [ -n "$TMP_ROOT" ] && [ -d "$TMP_ROOT" ]; then
    rm -rf "$TMP_ROOT"
  fi
}

die() {
  echo "ERROR: $*" >&2
  return 1
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "missing command: $1"
}

host_has_expected_ipv4() {
  ip -4 -o addr show scope global | awk '{print $4}' | cut -d/ -f1 | grep -Fx "$EXPECTED_HOST_IPV4" >/dev/null
}

package_installed() {
  dpkg-query -W -f='${Status}\n' "$1" 2>/dev/null | grep -x 'install ok installed' >/dev/null
}

snapshot_packages() {
  dpkg-query -W -f='${binary:Package}\n' 2>/dev/null | sort -u
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

rollback_on_error() {
  rc=$?
  trap - ERR
  echo "ERROR: AWG toolchain apply failed; reverting task-owned changes" >&2

  modprobe -r amneziawg >/dev/null 2>&1 || true

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

  rm -f "$SOURCE_FILE" "$KEYRING"
  rm -rf "$STATE_DIR"
  apt-get update >/dev/null 2>&1 || true
  cleanup_tmp
  exit "$rc"
}

[ "${EUID:-$(id -u)}" -eq 0 ] || die "run as root"

for cmd in git ip awk grep cut curl gpg apt-get apt-cache dpkg-query sha256sum sort comm mktemp install systemctl modprobe modinfo lsmod ss ufw sysctl xargs; do
  require_cmd "$cmd"
done

repo_root="$(git -c safe.directory="$PWD" rev-parse --show-toplevel 2>/dev/null)" || die "not inside a Git repository"
[ "$repo_root" = "$PWD" ] || die "run from repository root: $repo_root"
[ "$(git branch --show-current)" = "main" ] || die "run from main branch"
[ -z "$(git status --porcelain)" ] || die "working tree must be clean"
[ -f "$PROBE_SCRIPT" ] || die "missing probe: $PROBE_SCRIPT"
host_has_expected_ipv4 || die "host identity mismatch; expected IPv4 $EXPECTED_HOST_IPV4"

. /etc/os-release
[ "${ID:-}" = "$EXPECTED_OS_ID" ] || die "OS mismatch: ${ID:-unknown}"
[ "${VERSION_CODENAME:-}" = "$EXPECTED_OS_CODENAME" ] || die "suite mismatch: ${VERSION_CODENAME:-unknown}"
[ "$(dpkg --print-architecture)" = "$EXPECTED_ARCH" ] || die "architecture mismatch"

HEADER_PACKAGE="linux-headers-$(uname -r)"
package_installed "$HEADER_PACKAGE" || die "running-kernel headers are not installed: $HEADER_PACKAGE"

[ ! -e "$STATE_FILE" ] || die "managed AWG toolchain state already exists"
[ ! -e "$SOURCE_FILE" ] || die "managed APT source already exists"
[ ! -e "$KEYRING" ] || die "managed keyring already exists"

for pkg in "${PACKAGES[@]}"; do
  package_installed "$pkg" && die "package already installed outside this task: $pkg"
done

command -v awg >/dev/null 2>&1 && die "awg command already exists"
command -v awg-quick >/dev/null 2>&1 && die "awg-quick command already exists"
modinfo amneziawg >/dev/null 2>&1 && die "amneziawg module already exists"
ss -H -lunp 'sport = :443' | grep . >/dev/null && die "udp/443 is no longer free"
assert_protected_units_active

FIREWALL_ROUTE_HASH_BEFORE="$(snapshot_firewall_routes)"
REBOOT_REQUIRED_BEFORE="$([ -e /var/run/reboot-required ] && echo yes || echo no)"

bash "$PROBE_SCRIPT"

BACKUP_ID="$(date -u +%Y%m%dT%H%M%SZ)"
BACKUP_DIR="$BACKUP_ROOT/$BACKUP_ID"
mkdir -p "$BACKUP_DIR"
chmod 0700 "$BACKUP_DIR"
PKG_BEFORE="$BACKUP_DIR/packages.before"
snapshot_packages > "$PKG_BEFORE"
printf 'created_by\tscripts/apply_moscow_awg_toolchain.sh\ncreated_at_utc\t%s\ngit_head\t%s\n' \
  "$BACKUP_ID" "$(git rev-parse HEAD)" > "$BACKUP_DIR/MANIFEST.tsv"

TMP_ROOT="$(mktemp -d /tmp/vps-tier-awg-install.XXXXXX)"
chmod 0700 "$TMP_ROOT"
GNUPGHOME="$TMP_ROOT/gnupg"
KEY_ASC="$TMP_ROOT/amnezia.asc"
KEYRING_TMP="$TMP_ROOT/amnezia.gpg"
SOURCE_TMP="$TMP_ROOT/vps-tier-amnezia.sources"
mkdir -p "$GNUPGHOME"
chmod 0700 "$GNUPGHOME"

curl --fail --silent --show-error --location --proto '=https' --tlsv1.2 \
  "$KEY_URL" --output "$KEY_ASC"
gpg --batch --homedir "$GNUPGHOME" --import "$KEY_ASC" >/dev/null 2>&1
ACTUAL_FINGERPRINT="$(gpg --batch --homedir "$GNUPGHOME" --with-colons --fingerprint "$SIGNING_KEY_FINGERPRINT" | awk -F: '$1=="fpr" {print toupper($10); exit}')"
[ "$ACTUAL_FINGERPRINT" = "$SIGNING_KEY_FINGERPRINT" ] || die "signing-key fingerprint mismatch"
gpg --batch --homedir "$GNUPGHOME" --export "$SIGNING_KEY_FINGERPRINT" > "$KEYRING_TMP"

cat > "$SOURCE_TMP" <<EOF
Types: deb
URIs: $PPA_URI
Suites: noble
Components: main
Architectures: amd64
Signed-By: $KEYRING
EOF

trap rollback_on_error ERR
MUTATION_STARTED=1

install -o root -g root -m 0644 "$KEYRING_TMP" "$KEYRING"
install -o root -g root -m 0644 "$SOURCE_TMP" "$SOURCE_FILE"
apt-get update >/dev/null

for pkg in amneziawg amneziawg-dkms; do
  apt-cache policy "$pkg" | grep -F "$PPA_URI" >/dev/null || die "$pkg candidate is not from approved PPA"
done

AMNEZIAWG_CANDIDATE="$(apt-cache policy amneziawg | awk '/^[[:space:]]*Candidate:/ {print $2; exit}')"
AMNEZIAWG_DKMS_CANDIDATE="$(apt-cache policy amneziawg-dkms | awk '/^[[:space:]]*Candidate:/ {print $2; exit}')"
[ -n "$AMNEZIAWG_CANDIDATE" ] && [ "$AMNEZIAWG_CANDIDATE" != "(none)" ] || die "no amneziawg candidate"
[ -n "$AMNEZIAWG_DKMS_CANDIDATE" ] && [ "$AMNEZIAWG_DKMS_CANDIDATE" != "(none)" ] || die "no amneziawg-dkms candidate"

DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends --no-upgrade \
  dkms amneziawg amneziawg-dkms

command -v dkms >/dev/null 2>&1 || die "dkms command missing after install"
command -v awg >/dev/null 2>&1 || die "awg command missing after install"
command -v awg-quick >/dev/null 2>&1 || die "awg-quick command missing after install"
modinfo amneziawg >/dev/null 2>&1 || die "amneziawg module metadata missing"
dkms status | grep -F 'amneziawg/' | grep -F "$(uname -r)" | grep -F ': installed' >/dev/null || \
  die "DKMS module is not installed for running kernel"

ip -o link show | grep -Ei '(^|: )[[:alnum:]_.-]*(awg|amnezia)' >/dev/null && die "unexpected AWG interface exists before module test"
modprobe amneziawg
lsmod | grep '^amneziawg ' >/dev/null || die "module load test failed"
modprobe -r amneziawg
lsmod | grep '^amneziawg ' >/dev/null && die "module remained loaded after validation"

ss -H -lunp 'sport = :443' | grep . >/dev/null && die "udp/443 became occupied"
assert_protected_units_active
FIREWALL_ROUTE_HASH_AFTER="$(snapshot_firewall_routes)"
[ "$FIREWALL_ROUTE_HASH_AFTER" = "$FIREWALL_ROUTE_HASH_BEFORE" ] || die "firewall or route state changed"

mkdir -p "$STATE_DIR"
chmod 0700 "$STATE_DIR"
snapshot_packages > "$BACKUP_DIR/packages.after"
comm -13 "$PKG_BEFORE" "$BACKUP_DIR/packages.after" > "$NEW_PACKAGES_FILE"
chmod 0600 "$NEW_PACKAGES_FILE"

cat > "$STATE_FILE" <<EOF
owner=vps-tier
applied_at_utc=$BACKUP_ID
backup_set=$BACKUP_DIR
source_file=$SOURCE_FILE
keyring=$KEYRING
EOF
chmod 0600 "$STATE_FILE"

AMNEZIAWG_VERSION="$(dpkg-query -W -f='${Version}' amneziawg)"
AMNEZIAWG_DKMS_VERSION="$(dpkg-query -W -f='${Version}' amneziawg-dkms)"
DKMS_VERSION="$(dpkg-query -W -f='${Version}' dkms)"
REBOOT_REQUIRED_AFTER="$([ -e /var/run/reboot-required ] && echo yes || echo no)"
EVIDENCE_FILE="docs/observed/analysis/moscow_awg_toolchain_apply_${BACKUP_ID}.md"

cat > "$EVIDENCE_FILE" <<EOF
# Moscow AmneziaWG Toolchain — Apply Evidence

- UTC: $(date -u +%Y-%m-%dT%H:%M:%SZ)
- Git HEAD: $(git rev-parse HEAD)
- Host IPv4: $EXPECTED_HOST_IPV4
- OS: $ID $VERSION_ID $VERSION_CODENAME
- Kernel: $(uname -r)
- Kernel headers: $HEADER_PACKAGE
- Signing-key fingerprint: $ACTUAL_FINGERPRINT
- APT source: $PPA_URI noble main
- amneziawg candidate: $AMNEZIAWG_CANDIDATE
- amneziawg-dkms candidate: $AMNEZIAWG_DKMS_CANDIDATE
- amneziawg installed version: $AMNEZIAWG_VERSION
- amneziawg-dkms installed version: $AMNEZIAWG_DKMS_VERSION
- dkms installed version: $DKMS_VERSION
- DKMS build for running kernel: passed
- awg command: present
- awg-quick command: present
- Module load/unload test: passed
- AWG interface created: no
- UDP/443 changed: no
- Firewall, forwarding, and route state changed: no
- Protected units active before/after: yes
- Reboot-required before/after: $REBOOT_REQUIRED_BEFORE/$REBOOT_REQUIRED_AFTER
- Kazakhstan server changed: no
- Backup set: $BACKUP_DIR
- Secrets recorded: no
EOF

trap - ERR
MUTATION_STARTED=0
cleanup_tmp
TMP_ROOT=""

echo "DONE: Moscow AWG toolchain installed and validated"
echo "EVIDENCE_FILE=$EVIDENCE_FILE"
echo "BACKUP_SET=$BACKUP_DIR"
echo "AMNEZIAWG_VERSION=$AMNEZIAWG_VERSION"
echo "AMNEZIAWG_DKMS_VERSION=$AMNEZIAWG_DKMS_VERSION"
