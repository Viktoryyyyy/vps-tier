#!/usr/bin/env bash
set -Eeuo pipefail

EXPECTED_IPV4="147.45.184.140"
OUTPUT_DIR="/var/lib/vps-tier/iphone-awg-profile"
PROFILE_FILE="$OUTPUT_DIR/iphone-awg.conf"
STATE_FILE="$OUTPUT_DIR/state.env"

fail() { echo "ERROR: $*" >&2; exit 1; }
[ "${EUID:-$(id -u)}" -eq 0 ] || fail "run as root"
ip -4 -o addr show scope global | awk '{print $4}' | cut -d/ -f1 | grep -Fx "$EXPECTED_IPV4" >/dev/null || fail "host identity mismatch"
[ -r "$STATE_FILE" ] || fail "managed profile state missing"
# shellcheck disable=SC1090
. "$STATE_FILE"
[ "${owner:-}" = vps-tier ] || fail "state ownership mismatch"
[ "${profile_path:-}" = "$PROFILE_FILE" ] || fail "profile path mismatch"
[ -r "$PROFILE_FILE" ] || fail "managed profile file missing"
[ "$(sha256sum "$PROFILE_FILE" | awk '{print $1}')" = "${profile_sha256:-}" ] || fail "profile hash diverged; rollback blocked"
rm -rf "$OUTPUT_DIR"
[ ! -e "$OUTPUT_DIR" ] || fail "profile output directory still exists"
echo "DONE: iPhone AmneziaWG profile removed"
echo "STAGE5_KEYS=preserved"
echo "STAGE6_ROUTING=preserved"
