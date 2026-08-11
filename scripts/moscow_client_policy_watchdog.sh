#!/usr/bin/env bash
set -Eeuo pipefail

EXPECTED_IPV4="147.45.184.140"
TABLE_ID=1071
RULE_PRIORITY=10710
CLIENT_SUBNET="10.71.0.0/24"
STAGE6_STATE="/var/lib/vps-tier/moscow-fail-closed-routing/state.env"
POLICY_RUNTIME="/usr/local/libexec/vps-tier/moscow-client-policy-runtime"
POLICY_SERVICE="vps-tier-moscow-client-policy.service"

fail() { echo "ERROR: $*" >&2; exit 1; }
host_ok() { ip -4 -o addr show scope global | awk '{print $4}' | cut -d/ -f1 | grep -Fx "$EXPECTED_IPV4" >/dev/null; }
rule_at_priority() { ip -4 rule show | awk -v p="${RULE_PRIORITY}:" '$1==p {print $1, $2, $3, $4, $5}'; }
exact_rule() { rule_at_priority | grep -Fx "${RULE_PRIORITY}: from ${CLIENT_SUBNET} lookup ${TABLE_ID}" >/dev/null; }
prohibit_present() { ip -4 route show table "$TABLE_ID" | grep -E '^prohibit default.*metric 32760([[:space:]]|$)' >/dev/null; }

[ "${EUID:-$(id -u)}" -eq 0 ] || fail "run as root"
for cmd in awk cut grep ip systemctl; do command -v "$cmd" >/dev/null 2>&1 || fail "missing command: $cmd"; done
host_ok || fail "host identity mismatch"
[ -r "$STAGE6_STATE" ] || fail "Stage-6 managed state missing"
[ -x "$POLICY_RUNTIME" ] || fail "policy runtime helper missing or not executable"
systemctl is-active --quiet "$POLICY_SERVICE" || fail "policy barrier service inactive"

rule_ok=no
prohibit_ok=no
exact_rule && rule_ok=yes
prohibit_present && prohibit_ok=yes

if [ "$rule_ok" = yes ] && [ "$prohibit_ok" = yes ]; then
  echo "POLICY_WATCHDOG=ok"
  echo "RULE_10710=present"
  echo "PROHIBIT_DEFAULT=present"
  exit 0
fi

existing="$(rule_at_priority || true)"
if [ -n "$existing" ] && [ "$rule_ok" != yes ]; then
  fail "policy priority ${RULE_PRIORITY} occupied by unexpected rule; refusing repair"
fi

echo "POLICY_WATCHDOG=repair_required"
echo "RULE_10710_BEFORE=$rule_ok"
echo "PROHIBIT_DEFAULT_BEFORE=$prohibit_ok"

"$POLICY_RUNTIME" up

exact_rule || fail "policy rule missing after repair"
prohibit_present || fail "prohibit default missing after repair"

echo "POLICY_WATCHDOG=repaired"
echo "RULE_10710=restored"
echo "PROHIBIT_DEFAULT=restored"
