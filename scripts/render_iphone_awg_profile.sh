#!/usr/bin/env bash
set -Eeuo pipefail

SOURCE_HEAD="${VPS_TIER_SOURCE_HEAD:-}"
EXPECTED_IPV4="147.45.184.140"
CLIENT_ADDR="10.71.0.2/32"
ENDPOINT="147.45.184.140:443"
DNS_SERVER="1.1.1.1"
MTU="1280"
MATERIAL_DIR="/etc/amnezia/amneziawg/vps-tier/awg-client"
CLIENT_KEY="$MATERIAL_DIR/iphone.key"
CLIENT_PUB="$MATERIAL_DIR/iphone.pub"
SERVER_PUB="$MATERIAL_DIR/server.pub"
PARAMS_FILE="$MATERIAL_DIR/params.env"
STAGE5_STATE="/var/lib/vps-tier/moscow-awg-client-termination/state.env"
STAGE6_STATE="/var/lib/vps-tier/moscow-fail-closed-routing/state.env"
OUTPUT_PARENT="/var/lib/vps-tier"
OUTPUT_DIR="$OUTPUT_PARENT/iphone-awg-profile"
PROFILE_FILE="$OUTPUT_DIR/iphone-awg.conf"
STATE_FILE="$OUTPUT_DIR/state.env"
EVIDENCE_FILE="$OUTPUT_DIR/evidence.md"
TMP_DIR=""
PUBLISH_DIR=""
OUTPUT_OWNED=0
RENDER_SUCCESS=0

fail() { echo "ERROR: $*" >&2; exit 1; }
cleanup() {
  [ -z "$TMP_DIR" ] || rm -rf "$TMP_DIR"
  [ -z "$PUBLISH_DIR" ] || rm -rf "$PUBLISH_DIR"
  if [ "$RENDER_SUCCESS" -eq 0 ] && [ "$OUTPUT_OWNED" -eq 1 ]; then rm -rf "$OUTPUT_DIR"; fi
}
trap cleanup EXIT

[ "${EUID:-$(id -u)}" -eq 0 ] || fail "run as root"
[[ "$SOURCE_HEAD" =~ ^[0-9a-f]{40}$ ]] || fail "VPS_TIER_SOURCE_HEAD must be a full lowercase commit SHA"
ip -4 -o addr show scope global | awk '{print $4}' | cut -d/ -f1 | grep -Fx "$EXPECTED_IPV4" >/dev/null || fail "host identity mismatch"

for cmd in awk awg awg-quick cut grep install ip mktemp mv sha256sum stat sysctl systemctl tr; do command -v "$cmd" >/dev/null 2>&1 || fail "missing command: $cmd"; done
[ -r "$STAGE5_STATE" ] || fail "Stage-5 managed state missing"
[ -r "$STAGE6_STATE" ] || fail "Stage-6 managed state missing"
grep -Fx 'status=applied' "$STAGE6_STATE" >/dev/null || fail "Stage-6 managed state is not applied"
[ -d "$OUTPUT_PARENT" ] || fail "managed runtime parent missing"
[ ! -e "$OUTPUT_DIR" ] || fail "profile output already exists"
systemctl is-active --quiet awg-quick@awg-client.service || fail "AWG client service inactive"
systemctl is-active --quiet wg-quick@wg-backbone.service || fail "backbone service inactive"
systemctl is-active --quiet vps-tier-moscow-client-policy.service || fail "Stage-6 policy service inactive"
[ "$(sysctl -n net.ipv4.ip_forward)" = 1 ] || fail "Stage-6 IPv4 forwarding not active"
[ "$(sysctl -n net.ipv6.conf.all.forwarding)" = 0 ] || fail "IPv6 forwarding must remain disabled"
ip -4 rule show | grep -F '10710: from 10.71.0.0/24 lookup 1071' >/dev/null || fail "Stage-6 source policy rule missing"
ip -4 route show table 1071 | grep -E '^default dev wg-backbone .*metric 10([[:space:]]|$)' >/dev/null || fail "Stage-6 usable policy route missing"
ip -4 route show table 1071 | grep -E '^prohibit default metric 32760([[:space:]]|$)' >/dev/null || fail "Stage-6 prohibit fallback route missing"
ip -4 route get 1.1.1.1 from 10.71.0.2 iif awg-client | grep -F 'dev wg-backbone table 1071' >/dev/null || fail "Stage-6 policy lookup does not use backbone"

for f in "$CLIENT_KEY" "$CLIENT_PUB" "$SERVER_PUB" "$PARAMS_FILE"; do
  [ -r "$f" ] || fail "required runtime material missing: $f"
  [ "$(stat -c '%U:%G %a' "$f")" = "root:root 600" ] || fail "invalid ownership/mode: $f"
done

CLIENT_PUBLIC="$(tr -d '\r\n' < "$CLIENT_PUB")"
SERVER_PUBLIC="$(tr -d '\r\n' < "$SERVER_PUB")"
[ "$(awg pubkey < "$CLIENT_KEY")" = "$CLIENT_PUBLIC" ] || fail "client keypair mismatch"
[ "$(awg show awg-client public-key)" = "$SERVER_PUBLIC" ] || fail "server public key mismatch"
awg show awg-client peers | grep -Fx "$CLIENT_PUBLIC" >/dev/null || fail "client peer missing on server"
awg show awg-client allowed-ips | grep -F "$CLIENT_PUBLIC" | grep -F '10.71.0.2/32' >/dev/null || fail "server client AllowedIPs mismatch"

# shellcheck disable=SC1090
. "$PARAMS_FILE"
for n in Jc Jmin Jmax S1 S2 H1 H2 H3 H4; do [[ "${!n:-}" =~ ^[0-9]+$ ]] || fail "invalid AWG parameter: $n"; done
(( Jc >= 4 && Jc <= 12 )) || fail "Jc out of Stage-5 range"
(( Jmin == 8 && Jmax == 80 )) || fail "Jmin/Jmax differ from Stage-5 contract"
(( S1 >= 15 && S1 <= 150 && S2 >= 15 && S2 <= 150 && S1 + 56 != S2 )) || fail "S1/S2 invalid"
for h in H1 H2 H3 H4; do (( ${!h} >= 5 && ${!h} <= 2147483647 )) || fail "$h out of range"; done
[ "$H1" != "$H2" ] && [ "$H1" != "$H3" ] && [ "$H1" != "$H4" ] && [ "$H2" != "$H3" ] && [ "$H2" != "$H4" ] && [ "$H3" != "$H4" ] || fail "H1-H4 must be unique"

TMP_DIR="$(mktemp -d /tmp/vps-tier-iphone-awg.XXXXXX)"
chmod 0700 "$TMP_DIR"
TMP_PROFILE="$TMP_DIR/iphone-awg.conf"
CLIENT_PRIVATE="$(tr -d '\r\n' < "$CLIENT_KEY")"
umask 077
cat > "$TMP_PROFILE" <<PROFILE
[Interface]
PrivateKey = $CLIENT_PRIVATE
Address = $CLIENT_ADDR
DNS = $DNS_SERVER
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
unset CLIENT_PRIVATE CLIENT_PUBLIC SERVER_PUBLIC Jc Jmin Jmax S1 S2 H1 H2 H3 H4
chmod 0600 "$TMP_PROFILE"
awg-quick strip "$TMP_PROFILE" >/dev/null

PUBLISH_DIR="$(mktemp -d "$OUTPUT_PARENT/.iphone-awg-profile.XXXXXX")"
chmod 0700 "$PUBLISH_DIR"
PUBLISH_PROFILE="$PUBLISH_DIR/iphone-awg.conf"
PUBLISH_STATE="$PUBLISH_DIR/state.env"
PUBLISH_EVIDENCE="$PUBLISH_DIR/evidence.md"
install -o root -g root -m 0600 "$TMP_PROFILE" "$PUBLISH_PROFILE"
[ "$(stat -c '%U:%G %a' "$PUBLISH_DIR")" = "root:root 700" ] || fail "staging directory permissions invalid"
[ "$(stat -c '%U:%G %a' "$PUBLISH_PROFILE")" = "root:root 600" ] || fail "staged profile permissions invalid"
PROFILE_SHA="$(sha256sum "$PUBLISH_PROFILE" | awk '{print $1}')"
cat > "$PUBLISH_STATE" <<STATE
owner=vps-tier
source_head=$SOURCE_HEAD
profile_path=$PROFILE_FILE
profile_sha256=$PROFILE_SHA
client_address=$CLIENT_ADDR
endpoint=$ENDPOINT
dns=$DNS_SERVER
ipv4_full_tunnel=yes
ipv6_fail_closed_capture=yes
STATE
chmod 0600 "$PUBLISH_STATE"
cat > "$PUBLISH_EVIDENCE" <<EVIDENCE
# iPhone AmneziaWG Profile — Render Evidence

- Source Git HEAD: $SOURCE_HEAD
- Profile created server-locally: yes
- Profile path: $PROFILE_FILE
- Profile mode: 600
- Client address: $CLIENT_ADDR
- Endpoint: $ENDPOINT
- DNS resolver: $DNS_SERVER
- IPv4 full tunnel: yes
- IPv6 default captured by tunnel for fail-closed validation: yes
- Existing Stage-5 keypair reused: yes
- Existing AWG parameters reused: yes
- Profile parser validation: passed
- Complete profile or private material printed: no
- Profile SHA-256: $PROFILE_SHA
EVIDENCE
chmod 0600 "$PUBLISH_EVIDENCE"
[ "$(stat -c '%U:%G %a' "$PUBLISH_STATE")" = "root:root 600" ] || fail "staged state permissions invalid"
[ "$(stat -c '%U:%G %a' "$PUBLISH_EVIDENCE")" = "root:root 600" ] || fail "staged evidence permissions invalid"
[ "$(sha256sum "$PUBLISH_PROFILE" | awk '{print $1}')" = "$PROFILE_SHA" ] || fail "staged profile hash changed"

mv "$PUBLISH_DIR" "$OUTPUT_DIR"
PUBLISH_DIR=""
OUTPUT_OWNED=1
[ "$(stat -c '%U:%G %a' "$OUTPUT_DIR")" = "root:root 700" ] || fail "output directory permissions invalid"
[ "$(stat -c '%U:%G %a' "$PROFILE_FILE")" = "root:root 600" ] || fail "profile permissions invalid"
[ -r "$STATE_FILE" ] && [ -r "$EVIDENCE_FILE" ] || fail "published state/evidence missing"
[ "$(sha256sum "$PROFILE_FILE" | awk '{print $1}')" = "$PROFILE_SHA" ] || fail "published profile hash changed"
RENDER_SUCCESS=1

echo "DONE: iPhone AmneziaWG profile rendered"
echo "PROFILE_FILE=$PROFILE_FILE"
echo "PROFILE_MODE=600"
echo "PROFILE_SHA256=$PROFILE_SHA"
echo "DNS=$DNS_SERVER"
echo "IPV4_FULL_TUNNEL=yes"
echo "IPV6_FAIL_CLOSED_CAPTURE=yes"
echo "SECRETS_PRINTED=no"
