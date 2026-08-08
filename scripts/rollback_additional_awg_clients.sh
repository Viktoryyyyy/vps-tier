#!/usr/bin/env bash
set -Eeuo pipefail

EXPECTED_IPV4="147.45.184.140"
IFACE="awg-client"
CONFIG="/etc/amnezia/amneziawg/awg-client.conf"
EXTRA_MATERIAL="/etc/amnezia/amneziawg/vps-tier/awg-client/additional-clients"
OUTPUT_DIR="/var/lib/vps-tier/additional-awg-clients"
STATE_FILE="$OUTPUT_DIR/state.env"

fail() { echo "ERROR: $*" >&2; exit 1; }
[ "${EUID:-$(id -u)}" -eq 0 ] || fail "run as root"
ip -4 -o addr show scope global | awk '{print $4}' | cut -d/ -f1 | grep -Fx "$EXPECTED_IPV4" >/dev/null || fail "host identity mismatch"
[ -r "$STATE_FILE" ] || fail "managed additional-client state missing"
# shellcheck disable=SC1090
. "$STATE_FILE"
[ "${owner:-}" = "vps-tier" ] || fail "state ownership mismatch"
[ -r "${backup_dir:-}/awg-client.conf.before" ] || fail "managed config backup missing"
[ "$(sha256sum "$CONFIG" | awk '{print $1}')" = "${modified_config_sha256:-}" ] || fail "AWG config diverged; rollback blocked"
[ "$(sha256sum "$backup_dir/awg-client.conf.before" | awk '{print $1}')" = "${original_config_sha256:-}" ] || fail "backup hash mismatch"
[ "$(sha256sum "$OUTPUT_DIR/windows.conf" | awk '{print $1}')" = "${windows_profile_sha256:-}" ] || fail "Windows profile diverged"
[ "$(sha256sum "$OUTPUT_DIR/sber-tv.conf" | awk '{print $1}')" = "${tv_profile_sha256:-}" ] || fail "TV profile diverged"

awg set "$IFACE" peer "$windows_public_key" remove
awg set "$IFACE" peer "$tv_public_key" remove
install -o root -g root -m 0600 "$backup_dir/awg-client.conf.before" "$CONFIG"
rm -rf "$EXTRA_MATERIAL" "$OUTPUT_DIR"

echo "DONE: additional AmneziaWG clients removed"
echo "IPHONE_PEER=preserved"
echo "STAGE6_ROUTING=preserved"
