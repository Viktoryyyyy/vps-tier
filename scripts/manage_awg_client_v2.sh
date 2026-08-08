#!/usr/bin/env bash
set -Eeuo pipefail

MODE="${1:-}"
SOURCE_HEAD="${VPS_TIER_SOURCE_HEAD:-}"
DEVICE="${VPS_TIER_DEVICE_NAME:-}"
CLIENT_ADDR="${VPS_TIER_CLIENT_ADDRESS:-}"
EXPECTED_IPV4="147.45.184.140"
IFACE="awg-client"
CONFIG="/etc/amnezia/amneziawg/awg-client.conf"
BASE_MATERIAL="/etc/amnezia/amneziawg/vps-tier/awg-client"
SERVER_PUB="$BASE_MATERIAL/server.pub"
PARAMS_FILE="$BASE_MATERIAL/params.env"
CLIENT_ROOT="$BASE_MATERIAL/managed-clients"
OUTPUT_ROOT="/var/lib/vps-tier/managed-awg-clients"
BACKUP_ROOT="/var/backups/vps-tier/managed-awg-clients"
ENDPOINT="147.45.184.140:443"
DNS="1.1.1.1"
MTU="1280"
TMP_DIR=""
CONFIG_TMP=""
BACKUP_DIR=""
CLIENT_PUBLIC=""
CONFIG_REPLACED=0
RUNTIME_APPLIED=0

fail() { echo "ERROR: $*" >&2; return 1; }
cleanup() {
  [ -z "$TMP_DIR" ] || rm -rf "$TMP_DIR"
  [ -z "$CONFIG_TMP" ] || rm -f "$CONFIG_TMP"
}
trap cleanup EXIT

validate_common() {
  [ "${EUID:-$(id -u)}" -eq 0 ] || fail "run as root"
  [[ "$DEVICE" =~ ^[a-z0-9][a-z0-9-]{1,31}$ ]] || fail "VPS_TIER_DEVICE_NAME must be 2-32 lowercase letters, digits or hyphens"
  [[ "$CLIENT_ADDR" =~ ^10\.71\.0\.([0-9]{1,3})/32$ ]] || fail "VPS_TIER_CLIENT_ADDRESS must be 10.71.0.N/32"
  octet="${BASH_REMATCH[1]}"
  (( octet >= 2 && octet <= 254 )) || fail "client host octet must be 2..254"
  ip -4 -o addr show scope global | awk '{print $4}' | cut -d/ -f1 | grep -Fx "$EXPECTED_IPV4" >/dev/null || fail "host identity mismatch"
}

validate_apply_source() {
  [[ "$SOURCE_HEAD" =~ ^[0-9a-f]{40}$ ]] || fail "VPS_TIER_SOURCE_HEAD must be a full lowercase commit SHA"
  SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
  REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
  command -v git >/dev/null 2>&1 || fail "missing command: git"
  [ "$(git -C "$REPO_ROOT" rev-parse HEAD)" = "$SOURCE_HEAD" ] || fail "repository HEAD does not match VPS_TIER_SOURCE_HEAD"
}

atomic_restore_config() {
  local src="$1"
  local tmp="${CONFIG%/*}/awgrst.$$.conf"
  install -o root -g root -m 0600 "$src" "$tmp"
  awg-quick strip "$tmp" >/dev/null
  mv -f "$tmp" "$CONFIG"
}

apply_client() {
  validate_common
  validate_apply_source
  for cmd in awk awg awg-quick cp cut date dirname grep install ip mktemp mv rm sha256sum stat systemctl tr; do
    command -v "$cmd" >/dev/null 2>&1 || fail "missing command: $cmd"
  done
  systemctl is-active --quiet awg-quick@awg-client.service || fail "AWG service inactive"
  systemctl is-active --quiet wg-quick@wg-backbone.service || fail "backbone service inactive"
  systemctl is-active --quiet vps-tier-moscow-client-policy.service || fail "policy service inactive"
  [ -r /var/lib/vps-tier/moscow-awg-client-termination/state.env ] || fail "Stage-5 state missing"
  [ -r /var/lib/vps-tier/moscow-fail-closed-routing/state.env ] || fail "Stage-6 state missing"
  [ -r "$CONFIG" ] || fail "AWG server config missing"
  [ -r "$SERVER_PUB" ] || fail "server public key missing"
  [ -r "$PARAMS_FILE" ] || fail "AWG params missing"

  CLIENT_DIR="$CLIENT_ROOT/$DEVICE"
  OUTPUT_DIR="$OUTPUT_ROOT/$DEVICE"
  STATE_FILE="$OUTPUT_DIR/state.env"
  PROFILE_FILE="$OUTPUT_DIR/$DEVICE.conf"
  [ ! -e "$CLIENT_DIR" ] || fail "managed key material already exists for device"
  [ ! -e "$OUTPUT_DIR" ] || fail "managed output already exists for device"

  CURRENT_ALLOWED="$(awg show "$IFACE" allowed-ips)"
  printf '%s\n' "$CURRENT_ALLOWED" | awk '{for (i=2;i<=NF;i++) print $i}' | tr ',' '\n' | grep -Fx "$CLIENT_ADDR" >/dev/null && fail "client address already allocated at runtime"
  grep -F "AllowedIPs = $CLIENT_ADDR" "$CONFIG" >/dev/null && fail "client address already allocated persistently"

  BACKUP_ID="$(date -u +%Y%m%dT%H%M%SZ)"
  BACKUP_DIR="$BACKUP_ROOT/$DEVICE/apply/$BACKUP_ID"
  install -d -o root -g root -m 0700 "$BACKUP_DIR"
  install -o root -g root -m 0600 "$CONFIG" "$BACKUP_DIR/awg-client.conf.before"
  ORIGINAL_CONFIG_SHA="$(sha256sum "$CONFIG" | awk '{print $1}')"

  rollback_on_error() {
    rc=$?
    trap - ERR
    set +e
    if [ "$CONFIG_REPLACED" -eq 1 ] && [ -r "$BACKUP_DIR/awg-client.conf.before" ]; then
      atomic_restore_config "$BACKUP_DIR/awg-client.conf.before"
      if systemctl is-active --quiet awg-quick@awg-client.service; then
        awg syncconf "$IFACE" <(awg-quick strip "$CONFIG") >/dev/null 2>&1 || true
      fi
    elif [ "$RUNTIME_APPLIED" -eq 1 ] && [ -n "$CLIENT_PUBLIC" ]; then
      awg set "$IFACE" peer "$CLIENT_PUBLIC" remove >/dev/null 2>&1 || true
    fi
    rm -rf "$CLIENT_DIR" "$OUTPUT_DIR"
    echo "ERROR: managed AWG client apply failed; task-owned changes reverted" >&2
    exit "$rc"
  }
  trap rollback_on_error ERR

  install -d -o root -g root -m 0700 "$CLIENT_DIR"
  umask 077
  awg genkey > "$CLIENT_DIR/client.key"
  awg pubkey < "$CLIENT_DIR/client.key" > "$CLIENT_DIR/client.pub"
  chmod 0600 "$CLIENT_DIR/client.key" "$CLIENT_DIR/client.pub"
  CLIENT_PUBLIC="$(tr -d '\r\n' < "$CLIENT_DIR/client.pub")"
  SERVER_PUBLIC="$(tr -d '\r\n' < "$SERVER_PUB")"

  TMP_DIR="$(mktemp -d /tmp/vps-tier-awg-client.XXXXXX)"
  chmod 0700 "$TMP_DIR"
  SERVER_VALIDATE="$TMP_DIR/server.conf"
  cp "$CONFIG" "$SERVER_VALIDATE"
  printf '\n[Peer]\nPublicKey = %s\nAllowedIPs = %s\n' "$CLIENT_PUBLIC" "$CLIENT_ADDR" >> "$SERVER_VALIDATE"
  chmod 0600 "$SERVER_VALIDATE"
  awg-quick strip "$SERVER_VALIDATE" >/dev/null

  # shellcheck disable=SC1090
  . "$PARAMS_FILE"
  for n in Jc Jmin Jmax S1 S2 H1 H2 H3 H4; do
    [[ "${!n:-}" =~ ^[0-9]+$ ]] || fail "invalid AWG parameter: $n"
  done
  (( Jc >= 4 && Jc <= 12 )) || fail "Jc out of Stage-5 range"
  (( Jmin == 8 && Jmax == 80 )) || fail "Jmin/Jmax differ from Stage-5 contract"
  (( S1 >= 15 && S1 <= 150 && S2 >= 15 && S2 <= 150 && S1 + 56 != S2 )) || fail "S1/S2 invalid"

  CLIENT_PRIVATE="$(tr -d '\r\n' < "$CLIENT_DIR/client.key")"
  PROFILE_VALIDATE="$TMP_DIR/client.conf"
  printf '%s\n' \
    '[Interface]' \
    "PrivateKey = $CLIENT_PRIVATE" \
    "Address = $CLIENT_ADDR" \
    "DNS = $DNS" \
    "MTU = $MTU" \
    "Jc = $Jc" \
    "Jmin = $Jmin" \
    "Jmax = $Jmax" \
    "S1 = $S1" \
    "S2 = $S2" \
    "H1 = $H1" \
    "H2 = $H2" \
    "H3 = $H3" \
    "H4 = $H4" \
    '' \
    '[Peer]' \
    "PublicKey = $SERVER_PUBLIC" \
    "Endpoint = $ENDPOINT" \
    'AllowedIPs = 0.0.0.0/0, ::/0' \
    'PersistentKeepalive = 25' > "$PROFILE_VALIDATE"
  unset CLIENT_PRIVATE SERVER_PUBLIC Jc Jmin Jmax S1 S2 H1 H2 H3 H4
  chmod 0600 "$PROFILE_VALIDATE"
  awg-quick strip "$PROFILE_VALIDATE" >/dev/null

  CONFIG_TMP="${CONFIG%/*}/awgtmp.$$.conf"
  [ ! -e "$CONFIG_TMP" ] || fail "persistent temp config path already exists"
  install -o root -g root -m 0600 "$SERVER_VALIDATE" "$CONFIG_TMP"
  awg-quick strip "$CONFIG_TMP" >/dev/null
  mv -f "$CONFIG_TMP" "$CONFIG"
  CONFIG_TMP=""
  CONFIG_REPLACED=1
  MODIFIED_CONFIG_SHA="$(sha256sum "$CONFIG" | awk '{print $1}')"

  awg set "$IFACE" peer "$CLIENT_PUBLIC" allowed-ips "$CLIENT_ADDR"
  RUNTIME_APPLIED=1
  awg show "$IFACE" allowed-ips | grep -F "$CLIENT_PUBLIC" | grep -F "$CLIENT_ADDR" >/dev/null || fail "runtime peer verification failed"

  install -d -o root -g root -m 0700 "$OUTPUT_DIR"
  install -o root -g root -m 0600 "$PROFILE_VALIDATE" "$PROFILE_FILE"
  PROFILE_SHA="$(sha256sum "$PROFILE_FILE" | awk '{print $1}')"
  PROFILE_MODE="$(stat -c '%a' "$PROFILE_FILE")"
  [ "$PROFILE_MODE" = "600" ] || fail "profile permissions are not 600"

  printf '%s\n' \
    'owner=vps-tier' \
    "device=$DEVICE" \
    "source_head=$SOURCE_HEAD" \
    "client_address=$CLIENT_ADDR" \
    "client_public_key=$CLIENT_PUBLIC" \
    "backup_dir=$BACKUP_DIR" \
    "original_config_sha256=$ORIGINAL_CONFIG_SHA" \
    "modified_config_sha256=$MODIFIED_CONFIG_SHA" \
    "profile_file=$PROFILE_FILE" \
    "profile_sha256=$PROFILE_SHA" > "$STATE_FILE"
  chmod 0600 "$STATE_FILE"

  trap - ERR
  echo "DONE"
  echo "DEVICE=$DEVICE"
  echo "PROFILE_FILE=$PROFILE_FILE"
  echo "CLIENT_ADDRESS=$CLIENT_ADDR"
  echo "PROFILE_SHA256=$PROFILE_SHA"
  echo "SECRETS_PRINTED=no"
}

rollback_client() {
  validate_common
  for cmd in awk awg awg-quick cut grep install ip mv rm sha256sum systemctl; do
    command -v "$cmd" >/dev/null 2>&1 || fail "missing command: $cmd"
  done
  OUTPUT_DIR="$OUTPUT_ROOT/$DEVICE"
  STATE_FILE="$OUTPUT_DIR/state.env"
  [ -r "$STATE_FILE" ] || fail "managed client state missing"
  # shellcheck disable=SC1090
  . "$STATE_FILE"
  [ "${owner:-}" = "vps-tier" ] || fail "state ownership mismatch"
  [ "${device:-}" = "$DEVICE" ] || fail "state device mismatch"
  [ "${client_address:-}" = "$CLIENT_ADDR" ] || fail "state client address mismatch"
  [ -r "${backup_dir:-}/awg-client.conf.before" ] || fail "managed config backup missing"
  [ "$(sha256sum "$CONFIG" | awk '{print $1}')" = "${modified_config_sha256:-}" ] || fail "AWG config diverged; rollback blocked"
  [ "$(sha256sum "$backup_dir/awg-client.conf.before" | awk '{print $1}')" = "${original_config_sha256:-}" ] || fail "backup hash mismatch"
  [ -r "${profile_file:-}" ] || fail "managed profile missing"
  [ "$(sha256sum "$profile_file" | awk '{print $1}')" = "${profile_sha256:-}" ] || fail "profile hash mismatch"

  atomic_restore_config "$backup_dir/awg-client.conf.before"
  if systemctl is-active --quiet awg-quick@awg-client.service; then
    awg syncconf "$IFACE" <(awg-quick strip "$CONFIG") || fail "persistent config restored but runtime sync failed"
  fi
  rm -rf "$BASE_MATERIAL/managed-clients/$DEVICE" "$OUTPUT_DIR"

  echo "DONE"
  echo "DEVICE=$DEVICE"
  echo "CLIENT_ADDRESS=$CLIENT_ADDR"
  echo "STATUS=ROLLED_BACK"
  echo "SECRETS_PRINTED=no"
}

case "$MODE" in
  apply) apply_client ;;
  rollback) rollback_client ;;
  *) fail "usage: manage_awg_client_v2.sh {apply|rollback}" ;;
esac
