#!/usr/bin/env bash
set -Eeuo pipefail

EXPECTED_HOST_IPV4="147.45.184.140"
EXPECTED_OS_ID="ubuntu"
EXPECTED_OS_CODENAME="noble"
EXPECTED_ARCH="amd64"
PPA_URI="https://ppa.launchpadcontent.net/amnezia/ppa/ubuntu"
PPA_SUITE="noble"
PPA_COMPONENT="main"
SIGNING_KEY_FINGERPRINT="75C9DD72C799870E310542E24166F2C257290828"
KEY_URL="https://keyserver.ubuntu.com/pks/lookup?op=get&search=0x${SIGNING_KEY_FINGERPRINT}"
PACKAGES=(amneziawg amneziawg-dkms)

TMP_ROOT=""

cleanup() {
  rc=$?
  trap - EXIT
  if [ -n "$TMP_ROOT" ] && [ -d "$TMP_ROOT" ]; then
    rm -rf "$TMP_ROOT"
  fi
  exit "$rc"
}
trap cleanup EXIT

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

package_installed() {
  dpkg-query -W -f='${Status}\n' "$1" 2>/dev/null | grep -qx 'install ok installed'
}

capture_source_manifest() {
  out="$1"
  : > "$out"
  for path in /etc/apt/sources.list /etc/apt/sources.list.d/*; do
    [ -f "$path" ] || continue
    sha256sum "$path" >> "$out"
  done
  sort -o "$out" "$out"
}

apt_with_probe_config() {
  command_name="$1"
  shift
  "$command_name" -c "$APT_CONFIG" "$@"
}

candidate_for() {
  pkg="$1"
  apt_with_probe_config apt-cache policy "$pkg" |
    awk '/^[[:space:]]*Candidate:/ {print $2; exit}'
}

[ "${EUID:-$(id -u)}" -eq 0 ] || die "run as root"

for cmd in git ip awk grep cut curl gpg apt-get apt-cache dpkg-query dpkg-deb sha256sum find sort cmp mktemp; do
  require_cmd "$cmd"
done

repo_root="$(git -c safe.directory="$PWD" rev-parse --show-toplevel 2>/dev/null)" || die "not inside a Git repository"
[ "$repo_root" = "$PWD" ] || die "run from repository root: $repo_root"
[ "$(git branch --show-current)" = "main" ] || die "run from main branch"
[ -z "$(git status --porcelain)" ] || die "working tree must be clean"
host_has_expected_ipv4 || die "host identity mismatch; expected IPv4 $EXPECTED_HOST_IPV4"

. /etc/os-release
[ "${ID:-}" = "$EXPECTED_OS_ID" ] || die "OS mismatch: ${ID:-unknown}"
[ "${VERSION_CODENAME:-}" = "$EXPECTED_OS_CODENAME" ] || die "suite mismatch: ${VERSION_CODENAME:-unknown}"
[ "$(dpkg --print-architecture)" = "$EXPECTED_ARCH" ] || die "architecture mismatch"

HEADER_PACKAGE="linux-headers-$(uname -r)"
package_installed "$HEADER_PACKAGE" || die "running-kernel headers are not installed: $HEADER_PACKAGE"

for pkg in "${PACKAGES[@]}"; do
  package_installed "$pkg" && die "package already installed: $pkg"
done

if grep -RhsE '^[[:space:]]*deb(-src)? .*ppa\.launchpadcontent\.net/amnezia/ppa/ubuntu' \
  /etc/apt/sources.list /etc/apt/sources.list.d 2>/dev/null | grep -q .; then
  die "persistent Amnezia PPA source already exists"
fi

TMP_ROOT="$(mktemp -d /tmp/vps-tier-awg-probe.XXXXXX)"
chmod 0755 "$TMP_ROOT"
GNUPGHOME="$TMP_ROOT/gnupg"
KEY_ASC="$TMP_ROOT/amnezia.asc"
KEYRING="$TMP_ROOT/amnezia.gpg"
SOURCE_FILE="$TMP_ROOT/amnezia.list"
APT_CONFIG="$TMP_ROOT/apt.conf"
SOURCE_MANIFEST_BEFORE="$TMP_ROOT/apt-sources.before"
SOURCE_MANIFEST_AFTER="$TMP_ROOT/apt-sources.after"
DEB_DIR="$TMP_ROOT/debs"

mkdir -p "$GNUPGHOME" "$TMP_ROOT/state/lists/partial" "$TMP_ROOT/cache/archives/partial" "$DEB_DIR"
chmod 0700 "$GNUPGHOME"
chmod 0755 "$TMP_ROOT/state" "$TMP_ROOT/state/lists" "$TMP_ROOT/state/lists/partial" \
  "$TMP_ROOT/cache" "$TMP_ROOT/cache/archives" "$TMP_ROOT/cache/archives/partial" "$DEB_DIR"

capture_source_manifest "$SOURCE_MANIFEST_BEFORE"

curl --fail --silent --show-error --location \
  --proto '=https' --tlsv1.2 "$KEY_URL" --output "$KEY_ASC"

gpg --batch --homedir "$GNUPGHOME" --import "$KEY_ASC" >/dev/null 2>&1
ACTUAL_FINGERPRINT="$(
  gpg --batch --homedir "$GNUPGHOME" --with-colons --fingerprint "$SIGNING_KEY_FINGERPRINT" |
    awk -F: '$1=="fpr" {print toupper($10); exit}'
)"
[ "$ACTUAL_FINGERPRINT" = "$SIGNING_KEY_FINGERPRINT" ] || \
  die "signing-key fingerprint mismatch: $ACTUAL_FINGERPRINT"

gpg --batch --homedir "$GNUPGHOME" --export "$SIGNING_KEY_FINGERPRINT" > "$KEYRING"
chmod 0644 "$KEYRING"

printf 'deb [arch=%s signed-by=%s] %s %s %s\n' \
  "$EXPECTED_ARCH" "$KEYRING" "$PPA_URI" "$PPA_SUITE" "$PPA_COMPONENT" > "$SOURCE_FILE"
chmod 0644 "$SOURCE_FILE"

cat > "$APT_CONFIG" <<EOF
Dir::Etc::sourcelist "$SOURCE_FILE";
Dir::Etc::sourceparts "-";
Dir::State "$TMP_ROOT/state";
Dir::State::status "/var/lib/dpkg/status";
Dir::Cache "$TMP_ROOT/cache";
Acquire::Languages "none";
APT::Get::List-Cleanup "0";
EOF

apt_with_probe_config apt-get update >/dev/null

AMNEZIAWG_CANDIDATE="$(candidate_for amneziawg)"
AMNEZIAWG_DKMS_CANDIDATE="$(candidate_for amneziawg-dkms)"
[ -n "$AMNEZIAWG_CANDIDATE" ] && [ "$AMNEZIAWG_CANDIDATE" != "(none)" ] || \
  die "no installable candidate for amneziawg"
[ -n "$AMNEZIAWG_DKMS_CANDIDATE" ] && [ "$AMNEZIAWG_DKMS_CANDIDATE" != "(none)" ] || \
  die "no installable candidate for amneziawg-dkms"

for pkg in "${PACKAGES[@]}"; do
  candidate="$(candidate_for "$pkg")"
  (
    cd "$DEB_DIR"
    apt_with_probe_config apt-get download "$pkg=$candidate" >/dev/null
  )
done

AMNEZIAWG_DEB="$(find "$DEB_DIR" -maxdepth 1 -type f -name 'amneziawg_*.deb' -print -quit)"
AMNEZIAWG_DKMS_DEB="$(find "$DEB_DIR" -maxdepth 1 -type f -name 'amneziawg-dkms_*.deb' -print -quit)"
[ -n "$AMNEZIAWG_DEB" ] || die "downloaded amneziawg package not found"
[ -n "$AMNEZIAWG_DKMS_DEB" ] || die "downloaded amneziawg-dkms package not found"

AMNEZIAWG_PACKAGE_NAME="$(dpkg-deb -f "$AMNEZIAWG_DEB" Package)"
AMNEZIAWG_PACKAGE_VERSION="$(dpkg-deb -f "$AMNEZIAWG_DEB" Version)"
AMNEZIAWG_PACKAGE_ARCH="$(dpkg-deb -f "$AMNEZIAWG_DEB" Architecture)"
AMNEZIAWG_DEPENDS="$(dpkg-deb -f "$AMNEZIAWG_DEB" Depends)"
AMNEZIAWG_DKMS_PACKAGE_NAME="$(dpkg-deb -f "$AMNEZIAWG_DKMS_DEB" Package)"
AMNEZIAWG_DKMS_PACKAGE_VERSION="$(dpkg-deb -f "$AMNEZIAWG_DKMS_DEB" Version)"
AMNEZIAWG_DKMS_PACKAGE_ARCH="$(dpkg-deb -f "$AMNEZIAWG_DKMS_DEB" Architecture)"

[ "$AMNEZIAWG_PACKAGE_NAME" = "amneziawg" ] || die "unexpected package identity: $AMNEZIAWG_PACKAGE_NAME"
[ "$AMNEZIAWG_DKMS_PACKAGE_NAME" = "amneziawg-dkms" ] || die "unexpected package identity: $AMNEZIAWG_DKMS_PACKAGE_NAME"
printf '%s\n' "$AMNEZIAWG_DEPENDS" | grep -Eq 'amneziawg-dkms|amneziawg-modules' || \
  die "amneziawg dependency does not reference a supported module package"
dpkg-deb -c "$AMNEZIAWG_DKMS_DEB" | grep -Eq 'usr/src/amneziawg-[^/]+/' || \
  die "amneziawg-dkms package does not contain an expected /usr/src module tree"

AMNEZIAWG_SHA256="$(sha256sum "$AMNEZIAWG_DEB" | awk '{print $1}')"
AMNEZIAWG_DKMS_SHA256="$(sha256sum "$AMNEZIAWG_DKMS_DEB" | awk '{print $1}')"

capture_source_manifest "$SOURCE_MANIFEST_AFTER"
cmp -s "$SOURCE_MANIFEST_BEFORE" "$SOURCE_MANIFEST_AFTER" || \
  die "persistent APT source files changed during probe"

for pkg in "${PACKAGES[@]}"; do
  package_installed "$pkg" && die "package state changed during probe: $pkg"
done
command -v awg >/dev/null 2>&1 && die "awg command unexpectedly appeared during probe"
modinfo amneziawg >/dev/null 2>&1 && die "amneziawg module unexpectedly appeared during probe"

cat <<EOF
===== MOSCOW AWG PACKAGE METADATA PROBE =====
HOST_IPV4=$EXPECTED_HOST_IPV4
OS=$ID
SUITE=$VERSION_CODENAME
ARCH=$(dpkg --print-architecture)
KERNEL=$(uname -r)
HEADER_PACKAGE=$HEADER_PACKAGE
SIGNING_KEY_FINGERPRINT=$ACTUAL_FINGERPRINT
PPA_URI=$PPA_URI
PPA_SUITE=$PPA_SUITE
PPA_COMPONENT=$PPA_COMPONENT
AMNEZIAWG_CANDIDATE=$AMNEZIAWG_CANDIDATE
AMNEZIAWG_DKMS_CANDIDATE=$AMNEZIAWG_DKMS_CANDIDATE
AMNEZIAWG_PACKAGE_VERSION=$AMNEZIAWG_PACKAGE_VERSION
AMNEZIAWG_PACKAGE_ARCH=$AMNEZIAWG_PACKAGE_ARCH
AMNEZIAWG_DKMS_PACKAGE_VERSION=$AMNEZIAWG_DKMS_PACKAGE_VERSION
AMNEZIAWG_DKMS_PACKAGE_ARCH=$AMNEZIAWG_DKMS_PACKAGE_ARCH
AMNEZIAWG_SHA256=$AMNEZIAWG_SHA256
AMNEZIAWG_DKMS_SHA256=$AMNEZIAWG_DKMS_SHA256
DEPENDENCY_REFERENCES_MODULE_PACKAGE=yes
DKMS_SOURCE_TREE_PRESENT=yes
PERSISTENT_APT_SOURCE_CHANGE=none
PACKAGE_INSTALLATION=none
MODULE_LOAD=none
INTERFACE_CREATION=none
FIREWALL_CHANGE=none
ROUTING_CHANGE=none
DONE: Moscow AWG package metadata probe completed
EOF
