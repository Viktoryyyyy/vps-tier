#!/usr/bin/env bash
set -Eeuo pipefail

SOURCE_HEAD="${VPS_TIER_SOURCE_HEAD:-}"
EXPECTED_IPV4="147.45.184.140"
IFACE="awg-client"
CONFIG="/etc/amnezia/amneziawg/awg-client.conf"
BASE_MATERIAL="/etc/amnezia/amneziawg/vps-tier/awg-client"
SERVER_PUB="$BASE_MATERIAL/server.pub"
PARAMS_FILE="$BASE_MATERIAL/params.env"
EXTRA_MATERIAL="$BASE_MATERIAL/additional-clients"
OUTPUT_DIR="/var/lib/vps-tier/additional-awg-clients"
STATE_FILE="$OUTPUT_DIR/state.env"
BACKUP_ROOT="/var/backups/vps-tier/additional-awg-clients/apply"
WIN_ADDR="10.71.0.3/32"
TV_ADDR="10.71.0.4/32"
ENDPOINT="147.45.184.140:443"
DNS="1.1.1.1"
MTU="1280"
TMP_DIR=""
BACKUP_DIR=""
CONFIG_REPLACED=0
WIN_RUNTIME=0
TV_RUNTIME=0

fail() { echo "ERROR: $*" >&2; exit 1; }
cleanup() { [ -z "$TMP_DIR" ] || rm -rf "$TMP_DIR"; }
rollback_on_error() {
  rc=$?
  trap - ERR
  set +e
  [ "$TV_RUNTIME" -eq 0 ] || awg set "$IFACE" peer "$TV_PUBLIC" remove >/dev/null 2>&1
  [ "$WIN_RUNTIME" -eq 0 ] || awg set "$IFACE" peer "$WIN_PUBLIC" remove >/dev/null 2>&1
  if [ "$CONFIG_REPLACED" -eq 1 ] && [ -r "$BACKUP_DIR/awg-client.conf.before" ]; then
    install -o root -g root -m 0600 "$BACKUP_DIR/awg-client.conf.before" "$CONFIG"
  fi
  rm -rf "$EXTRA_MATERIAL" "$OUTPUT_DIR"
  echo "ERROR: additional AWG client apply failed; task-owned changes reverted" >&2
  exit "$rc"
}
trap cleanup EXIT

[ "${EUID:-$(id -u)}" -eq 0 ] || fail "run as root"
[[ "$SOURCE_HEAD" =~ ^[0-9a-f]{40}$ ]] || fail "VPS_TIER_SOURCE_HEAD must be a full lowercase commit SHA"
for cmd in awk awg awg-quick cp cut date grep install ip mktemp sha256sum stat systemctl tr; do
  command -v "$cmd" >/dev/null 2>&1 || fail "missing command: $cmd"
done
ip -4 -o addr show scope global | awk '{print $4}' | cut -d/ -f1 | grep -Fx "$EXPECTED_IPV4" >/dev/null || fail "host identity mismatch"
systemctl is-active --quiet awg-quick@awg-client.service || fail "AWG service inactive"
systemctl is-active --quiet wg-quick@wg-backbone.service || fail "backbone service inactive"
systemctl is-active --quiet vps-tier-moscow-client-policy.service || fail "policy service inactive"
[ -r /var/lib/vps-tier/moscow-awg-client-termination/state.env ] || fail "Stage-5 state missing"
[ -r /var/lib/vps-tier/moscow-fail-closed-routing/state.env ] || fail "Stage-6 state missing"
[ -r "$CONFIG" ] || fail "AWG server config missing"
[ -r "$SERVER_PUB" ] || fail "server public key missing"
[ -r "$PARAMS_FILE" ] || fail "AWG params missing"
[ ! -e "$EXTRA_MATERIAL" ] || fail "additional client material already exists"
[ ! -e "$OUTPUT_DIR" ] || fail "additional client output already exists"

CURRENT_ALLOWED="$(awg show "$IFACE" allowed-ips)"
printf '%s\n' "$CURRENT_ALLOWED" | grep -F "$WIN_ADDR" >/dev/null && fail "Windows client address already allocated"
printf '%s\n' "$CURRENT_ALLOWED" | grep -F "$TV_ADDR" >/dev/null && fail "TV client address already allocated"

BACKUP_ID="$(date -u +%Y%m%dT%H%M%SZ)"
BACKUP_DIR="$BACKUP_ROOT/$BACKUP_ID"
install -d -o root -g root -m 0700 "$BACKUP_DIR"
install -o root -g root -m 0600 "$CONFIG" "$BACKUP_DIR/awg-client.conf.before"
ORIGINAL_CONFIG_SHA="$(sha256sum "$CONFIG" | awk '{print $1}')"

trap rollback_on_error ERR
install -d -o root -g root -m 0700 "$EXTRA_MATERIAL"
umask 077
awg genkey > "$EXTRA_MATERIAL/windows.key"
awg pubkey < "$EXTRA_MATERIAL/windows.key" > "$EXTRA_MATERIAL/windows.pub"
awg genkey > "$EXTRA_MATERIAL/sber-tv.key"
awg pubkey < "$EXTRA_MATERIAL/sber-tv.key" > "$EXTRA_MATERIAL/sber-tv.pub"
chmod 0600 "$EXTRA_MATERIAL/"*

WIN_PUBLIC="$(tr -d '\r\n' < "$EXTRA_MATERIAL/windows.pub")"
TV_PUBLIC="$(tr -d '\r\n' < "$EXTRA_MATERIAL/sber-tv.pub")"
SERVER_PUBLIC="$(tr -d '\r\n' < "$SERVER_PUB")"

TMP_DIR="$(mktemp -d /tmp/vps-tier-extra-awg.XXXXXX)"
chmod 0700 "$TMP_DIR"
NEW_CONFIG="$TMP_DIR/awg-client.conf"
cp "$CONFIG" "$NEW_CONFIG"
cat >> "$NEW_CONFIG" <<CFG

[Peer]
PublicKey = $WIN_PUBLIC
AllowedIPs = $WIN_ADDR

[Peer]
PublicKey = $TV_PUBLIC
AllowedIPs = $TV_ADDR
CFG
chmod 0600 "$NEW_CONFIG"
awg-quick strip "$NEW_CONFIG" >/dev/null

# shellcheck disable=SC1090
. "$PARAMS_FILE"
for n in Jc Jmin Jmax S1 S2 H1 H2 H3 H4; do
  [[ "${!n:-}" =~ ^[0-9]+$ ]] || fail "invalid AWG parameter: $n"
done

WIN_PRIVATE="$(tr -d '\r\n' < "$EXTRA_MATERIAL/windows.key")"
TV_PRIVATE="$(tr -d '\r\n' < "$EXTRA_MATERIAL/sber-tv.key")"
WIN_PROFILE="$TMP_DIR/windows.conf"
TV_PROFILE="$TMP_DIR/sber-tv.conf"

cat > "$WIN_PROFILE" <<PROFILE
[Interface]
PrivateKey = $WIN_PRIVATE
Address = $WIN_ADDR
DNS = $DNS
MTU = $MTU
Jc = $Jc
Jmin = $Jmin
Jmax = $Jmax
S1 = $S1
S2 = $S2
H1 = $H1
H2 = $H2
H3 = $H3
H4 = $H4

[Peer]
PublicKey = $SERVER_PUBLIC
Endpoint = $ENDPOINT
AllowedIPs = 0.0.0.0/0, ::/0
PersistentKeepalive = 25
PROFILE

cat > "$TV_PROFILE" <<PROFILE
[Interface]
PrivateKey = $TV_PRIVATE
Address = $TV_ADDR
DNS = $DNS
MTU = $MTU
Jc = $Jc
Jmin = $Jmin
Jmax = $Jmax
S1 = $S1
S2 = $S2
H1 = $H1
H2 = $H2
H3 = $H3
H4 = $H4

[Peer]
PublicKey = $SERVER_PUBLIC
Endpoint = $ENDPOINT
AllowedIPs = 0.0.0.0/0, ::/0
PersistentKeepalive = 25
PROFILE
unset WIN_PRIVATE TV_PRIVATE SERVER_PUBLIC Jc Jmin Jmax S1 S2 H1 H2 H3 H4
chmod 0600 "$WIN_PROFILE" "$TV_PROFILE"
awg-quick strip "$WIN_PROFILE" >/dev/null
awg-quick strip "$TV_PROFILE" >/dev/null

install -o root -g root -m 0600 "$NEW_CONFIG" "$CONFIG"
CONFIG_REPLACED=1
MODIFIED_CONFIG_SHA="$(sha256sum "$CONFIG" | awk '{print $1}')"

awg set "$IFACE" peer "$WIN_PUBLIC" allowed-ips "$WIN_ADDR"
WIN_RUNTIME=1
awg set "$IFACE" peer "$TV_PUBLIC" allowed-ips "$TV_ADDR"
TV_RUNTIME=1
awg show "$IFACE" allowed-ips | grep -F "$WIN_PUBLIC" | grep -F "$WIN_ADDR" >/dev/null || fail "Windows runtime peer verification failed"
awg show "$IFACE" allowed-ips | grep -F "$TV_PUBLIC" | grep -F "$TV_ADDR" >/dev/null || fail "TV runtime peer verification failed"

install -d -o root -g root -m 0700 "$OUTPUT_DIR"
install -o root -g root -m 0600 "$WIN_PROFILE" "$OUTPUT_DIR/windows.conf"
install -o root -g root -m 0600 "$TV_PROFILE" "$OUTPUT_DIR/sber-tv.conf"
WIN_SHA="$(sha256sum "$OUTPUT_DIR/windows.conf" | awk '{print $1}')"
TV_SHA="$(sha256sum "$OUTPUT_DIR/sber-tv.conf" | awk '{print $1}')"

cat > "$STATE_FILE" <<STATE
owner=vps-tier
source_head=$SOURCE_HEAD
backup_dir=$BACKUP_DIR
original_config_sha256=$ORIGINAL_CONFIG_SHA
modified_config_sha256=$MODIFIED_CONFIG_SHA
windows_public_key=$WIN_PUBLIC
windows_address=$WIN_ADDR
windows_profile_sha256=$WIN_SHA
tv_public_key=$TV_PUBLIC
tv_address=$TV_ADDR
tv_profile_sha256=$TV_SHA
STATE
chmod 0600 "$STATE_FILE"

echo "DONE: additional AmneziaWG clients provisioned"
echo "WINDOWS_PROFILE=$OUTPUT_DIR/windows.conf"
echo "WINDOWS_ADDRESS=$WIN_ADDR"
echo "WINDOWS_SHA256=$WIN_SHA"
echo "TV_PROFILE=$OUTPUT_DIR/sber-tv.conf"
echo "TV_ADDRESS=$TV_ADDR"
echo "TV_SHA256=$TV_SHA"
echo "IPHONE_PEER=preserved"
echo "SECRETS_PRINTED=no"
