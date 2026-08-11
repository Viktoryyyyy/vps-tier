#!/usr/bin/env bash
set -Eeuo pipefail

EXPECTED_IPV4="147.45.184.140"
TABLE_ID=1071
RULE_PRIORITY=10710
CLIENT_SUBNET="10.71.0.0/24"
WATCHDOG_TARGET="/usr/local/libexec/vps-tier/moscow-client-policy-watchdog"
SERVICE_TARGET="/etc/systemd/system/vps-tier-moscow-client-policy-watchdog.service"
TIMER_TARGET="/etc/systemd/system/vps-tier-moscow-client-policy-watchdog.timer"
STATE_DIR="/var/lib/vps-tier/moscow-client-policy-watchdog"
STATE_FILE="$STATE_DIR/state.env"

fail() { echo "ERROR: $*" >&2; exit 1; }
host_ok() { ip -4 -o addr show scope global | awk '{print $4}' | cut -d/ -f1 | grep -Fx "$EXPECTED_IPV4" >/dev/null; }
priority_rules() { ip -4 rule show | awk -v p="${RULE_PRIORITY}:" '$1==p {$1=$1; print}'; }
exact_rule() {
  local rules count
  rules="$(priority_rules)"
  count="$(printf '%s\n' "$rules" | awk 'NF{n++} END{print n+0}')"
  [ "$count" -eq 1 ] && [ "$rules" = "${RULE_PRIORITY}: from ${CLIENT_SUBNET} lookup ${TABLE_ID}" ]
}
prohibit_present() { ip -4 route show table "$TABLE_ID" | grep -E '^prohibit default.*metric 32760([[:space:]]|$)' >/dev/null; }

[ "${EUID:-$(id -u)}" -eq 0 ] || fail "run as root"
for cmd in awk cut grep ip rm sha256sum systemctl; do command -v "$cmd" >/dev/null 2>&1 || fail "missing command: $cmd"; done
host_ok || fail "host identity mismatch"
[ -r "$STATE_FILE" ] || fail "watchdog managed state missing"
# shellcheck disable=SC1090
. "$STATE_FILE"
[ "${owner:-}" = vps-tier ] || fail "state ownership mismatch"
[ "${status:-}" = applied ] || fail "unexpected managed state status"
[ -r "$WATCHDOG_TARGET" ] || fail "watchdog runtime target missing"
[ -r "$SERVICE_TARGET" ] || fail "watchdog service target missing"
[ -r "$TIMER_TARGET" ] || fail "watchdog timer target missing"
[ "$(sha256sum "$WATCHDOG_TARGET" | awk '{print $1}')" = "${watchdog_sha256:-}" ] || fail "watchdog runtime diverged; rollback blocked"
[ "$(sha256sum "$SERVICE_TARGET" | awk '{print $1}')" = "${service_sha256:-}" ] || fail "watchdog service diverged; rollback blocked"
[ "$(sha256sum "$TIMER_TARGET" | awk '{print $1}')" = "${timer_sha256:-}" ] || fail "watchdog timer diverged; rollback blocked"
exact_rule || fail "Stage-6 exact single policy rule unhealthy; repair Stage 6 before watchdog rollback"
prohibit_present || fail "Stage-6 prohibit default unhealthy; repair Stage 6 before watchdog rollback"

systemctl disable --now vps-tier-moscow-client-policy-watchdog.timer >/dev/null 2>&1 || true
systemctl stop vps-tier-moscow-client-policy-watchdog.service >/dev/null 2>&1 || true
rm -f "$WATCHDOG_TARGET" "$SERVICE_TARGET" "$TIMER_TARGET"
systemctl daemon-reload
rm -rf "$STATE_DIR"

exact_rule || fail "Stage-6 exact single policy rule changed during watchdog rollback"
prohibit_present || fail "Stage-6 prohibit default changed during watchdog rollback"

echo "DONE: Moscow client policy watchdog rolled back"
echo "WATCHDOG_TIMER=removed"
echo "STAGE6_POLICY=preserved"
echo "SECRETS_PRINTED=no"
