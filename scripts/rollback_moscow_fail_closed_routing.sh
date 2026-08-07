#!/usr/bin/env bash
set -Eeuo pipefail

EXPECTED_IPV4="147.45.184.140"
CLIENT_SUBNET="10.71.0.0/24"
AWG_IF="awg-client"
WG_IF="wg-backbone"
TABLE_ID="1071"
RULE_PRIORITY="10710"
KZ_TUNNEL_IP="10.70.0.2"
KZ_PUBLIC_KEY="SXeu14QxklfRSCu7r/ePgYYPwasKobsk8jUWAsIeGhs="
BASE_ALLOWED="10.70.0.2/32"
WG_CONF="/etc/wireguard/wg-backbone.conf"
WG_TMP="${WG_CONF}.vps-tier-stage6.tmp"
SYSCTL_FILE="/etc/sysctl.d/99-vps-tier-moscow-client-routing.conf"
POLICY_RUNTIME="/usr/local/libexec/vps-tier/moscow-client-policy-runtime"
POLICY_UNIT_NAME="vps-tier-moscow-client-policy.service"
POLICY_UNIT="/etc/systemd/system/$POLICY_UNIT_NAME"
AWG_DROPIN_DIR="/etc/systemd/system/awg-quick@awg-client.service.d"
AWG_DROPIN="$AWG_DROPIN_DIR/20-vps-tier-fail-closed.conf"
STATE_DIR="/var/lib/vps-tier/moscow-fail-closed-routing"
STATE_FILE="$STATE_DIR/state.env"
UFW_FORWARD_COMMENT="vps-tier-moscow-client-forward"
UFW_DENY_COMMENT="vps-tier-moscow-client-no-fallback"

fail() { echo "ERROR: $*" >&2; exit 1; }
host_ok() { ip -4 -o addr show scope global | awk '{print $4}' | cut -d/ -f1 | grep -Fx "$EXPECTED_IPV4" >/dev/null; }
runtime_allowed_ips() { wg show "$WG_IF" dump | awk -F '\t' -v key="$KZ_PUBLIC_KEY" '$1==key {print $4}'; }
ufw_has_marker() { ufw status numbered 2>/dev/null | grep -F "$1" >/dev/null; }
remove_ufw_marker() {
  marker="$1"
  while ufw_has_marker "$marker"; do
    num="$(ufw status numbered | sed -nE "s/^\[[[:space:]]*([0-9]+)\].*${marker}.*/\1/p" | head -n1)"
    [ -n "$num" ] || fail "cannot identify owned UFW rule: $marker"
    ufw --force delete "$num" >/dev/null
  done
}
priority_rule_lines() { ip -4 rule show | awk -v p="${RULE_PRIORITY}:" '$1==p {print $1, $2, $3, $4, $5}'; }
exact_policy_rule() { priority_rule_lines | grep -Fx "${RULE_PRIORITY}: from ${CLIENT_SUBNET} lookup ${TABLE_ID}" >/dev/null; }
remove_policy_barrier() {
  while exact_policy_rule; do ip -4 rule del priority "$RULE_PRIORITY" from "$CLIENT_SUBNET" lookup "$TABLE_ID"; done
  ip -4 route del prohibit default table "$TABLE_ID" metric 32760 2>/dev/null || true
}

[ "${EUID:-$(id -u)}" -eq 0 ] || fail "run as root"
host_ok || fail "host identity mismatch"
[ -r "$STATE_FILE" ] || fail "managed Stage-6 state missing"
# shellcheck disable=SC1090
. "$STATE_FILE"
[ "${owner:-}" = vps-tier ] || fail "state ownership mismatch"
case "${status:-}" in applying|applied) ;; *) fail "unexpected managed state status" ;; esac
[ "${client_subnet:-}" = "$CLIENT_SUBNET" ] || fail "state client subnet mismatch"
[ "${policy_table:-}" = "$TABLE_ID" ] || fail "state policy table mismatch"
[ "${policy_priority:-}" = "$RULE_PRIORITY" ] || fail "state policy priority mismatch"
[ "${wg_config_path:-}" = "$WG_CONF" ] || fail "state WireGuard config path mismatch"
[ -n "${backup_set:-}" ] && [ -r "$backup_set/wg-backbone.conf.before" ] || fail "baseline WireGuard backup missing"
[ "$(sha256sum "$backup_set/wg-backbone.conf.before" | awk '{print $1}')" = "${baseline_config_sha256:-}" ] || fail "baseline WireGuard backup hash mismatch"

if [ -e "$WG_CONF" ]; then
  current_sha="$(sha256sum "$WG_CONF" | awk '{print $1}')"
  case "$current_sha" in
    "${baseline_config_sha256:-}"|"${applied_config_sha256:-}") ;;
    *) fail "current WireGuard config diverged; rollback blocked" ;;
  esac
fi

DEFAULT_ROUTE_BEFORE="$(ip -4 route show default)"
[ "$(sysctl -n net.ipv6.conf.all.forwarding)" = 0 ] || fail "IPv6 forwarding diverged from Stage-6 managed state"
existing_priority="$(priority_rule_lines || true)"
if [ -n "$existing_priority" ] && ! exact_policy_rule; then fail "policy priority diverged; rollback blocked"; fi

# Close forwarding first, before removing either fail-closed barrier.
sysctl -w net.ipv4.ip_forward=0 >/dev/null
remove_ufw_marker "$UFW_FORWARD_COMMENT"
remove_ufw_marker "$UFW_DENY_COMMENT"
ip -4 route del default dev "$WG_IF" table "$TABLE_ID" metric 10 2>/dev/null || true

install -o root -g root -m 0600 "$backup_set/wg-backbone.conf.before" "$WG_TMP"
mv -f "$WG_TMP" "$WG_CONF"

if ip link show "$WG_IF" >/dev/null 2>&1; then
  wg set "$WG_IF" peer "$KZ_PUBLIC_KEY" allowed-ips "$BASE_ALLOWED"
fi

systemctl disable --now "$POLICY_UNIT_NAME" >/dev/null 2>&1 || true
remove_policy_barrier
rm -f "$AWG_DROPIN" "$POLICY_UNIT" "$POLICY_RUNTIME" "$SYSCTL_FILE"
rmdir "$AWG_DROPIN_DIR" 2>/dev/null || true
systemctl daemon-reload

if ! systemctl is-active --quiet wg-quick@wg-backbone.service; then
  systemctl start wg-quick@wg-backbone.service
fi
if ip link show "$WG_IF" >/dev/null 2>&1; then
  wg set "$WG_IF" peer "$KZ_PUBLIC_KEY" allowed-ips "$BASE_ALLOWED"
fi
sysctl -w net.ipv4.ip_forward=0 >/dev/null
sysctl -w net.ipv6.conf.all.forwarding=0 >/dev/null

[ "$(sysctl -n net.ipv4.ip_forward)" = 0 ] || fail "IPv4 forwarding not restored to Stage-5 baseline"
[ "$(sysctl -n net.ipv6.conf.all.forwarding)" = 0 ] || fail "IPv6 forwarding not restored to Stage-5 baseline"
[ "$(ip -4 route show default)" = "$DEFAULT_ROUTE_BEFORE" ] || fail "Moscow default route changed during rollback"
[ -z "$(priority_rule_lines || true)" ] || fail "policy priority still occupied after rollback"
[ -z "$(ip -4 route show table "$TABLE_ID" 2>/dev/null || true)" ] || fail "managed policy table still contains routes"
ufw_has_marker "$UFW_FORWARD_COMMENT" && fail "client-forward UFW rule still present"
ufw_has_marker "$UFW_DENY_COMMENT" && fail "no-fallback UFW rule still present"
[ ! -e "$SYSCTL_FILE" ] || fail "managed sysctl file still present"
[ ! -e "$POLICY_RUNTIME" ] || fail "policy runtime helper still present"
[ ! -e "$POLICY_UNIT" ] || fail "policy unit still present"
[ ! -e "$AWG_DROPIN" ] || fail "AWG drop-in still present"
systemctl is-enabled --quiet "$POLICY_UNIT_NAME" && fail "policy unit still enabled" || true
systemctl is-active --quiet wg-quick@wg-backbone.service || fail "backbone unit not active after rollback"
systemctl is-active --quiet awg-quick@awg-client.service || fail "AWG client unit not active after rollback"
[ "$(runtime_allowed_ips)" = "$BASE_ALLOWED" ] || fail "backbone runtime AllowedIPs not restored"
ping -c 1 -W 2 "$KZ_TUNNEL_IP" >/dev/null || fail "backbone ping failed after rollback"

ROLLBACK_EVIDENCE="$backup_set/rollback-evidence.md"
cat > "$ROLLBACK_EVIDENCE" <<EVIDENCE
# Moscow Fail-Closed Client Routing — Rollback Evidence

- UTC: $(date -u +%Y-%m-%dT%H:%M:%SZ)
- IPv4 forwarding restored to Stage-5 baseline: 0
- Stage-6 policy rule removed: yes
- Stage-6 policy table routes removed: yes
- Backbone AllowedIPs restored to: $BASE_ALLOWED
- Managed UFW client-forward rule removed: yes
- Managed UFW no-fallback rule removed: yes
- Managed sysctl/service/drop-in files removed: yes
- Moscow default route changed: no
- Backbone active and pingable: yes
- AWG client termination preserved: yes
- Secrets recorded: no
EVIDENCE
chmod 0600 "$ROLLBACK_EVIDENCE"
rm -rf "$STATE_DIR"

echo "DONE: Moscow fail-closed client routing rollback complete"
echo "IPV4_FORWARDING=0"
echo "BACKBONE_ALLOWED_IPS=$BASE_ALLOWED"
echo "AWG_CLIENT=preserved"
echo "ROLLBACK_EVIDENCE=$ROLLBACK_EVIDENCE"
