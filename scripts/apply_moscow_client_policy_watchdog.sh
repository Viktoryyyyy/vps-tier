#!/usr/bin/env bash
set -Eeuo pipefail

SOURCE_HEAD="${VPS_TIER_SOURCE_HEAD:-}"
EXPECTED_IPV4="147.45.184.140"
TABLE_ID=1071
RULE_PRIORITY=10710
CLIENT_SUBNET="10.71.0.0/24"
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
WATCHDOG_SOURCE="$SCRIPT_DIR/moscow_client_policy_watchdog.sh"
SERVICE_SOURCE="$REPO_ROOT/templates/systemd/vps-tier-moscow-client-policy-watchdog.service"
TIMER_SOURCE="$REPO_ROOT/templates/systemd/vps-tier-moscow-client-policy-watchdog.timer"
WATCHDOG_TARGET="/usr/local/libexec/vps-tier/moscow-client-policy-watchdog"
SERVICE_TARGET="/etc/systemd/system/vps-tier-moscow-client-policy-watchdog.service"
TIMER_TARGET="/etc/systemd/system/vps-tier-moscow-client-policy-watchdog.timer"
STAGE6_STATE="/var/lib/vps-tier/moscow-fail-closed-routing/state.env"
STATE_DIR="/var/lib/vps-tier/moscow-client-policy-watchdog"
STATE_FILE="$STATE_DIR/state.env"
POLICY_RUNTIME="/usr/local/libexec/vps-tier/moscow-client-policy-runtime"
POLICY_SERVICE="vps-tier-moscow-client-policy.service"
MUTATED=0

fail() { echo "ERROR: $*" >&2; return 1; }
host_ok() { ip -4 -o addr show scope global | awk '{print $4}' | cut -d/ -f1 | grep -Fx "$EXPECTED_IPV4" >/dev/null; }
priority_rules() { ip -4 rule show | awk -v p="${RULE_PRIORITY}:" '$1==p {$1=$1; print}'; }
exact_rule() {
  local rules count
  rules="$(priority_rules)"
  count="$(printf '%s\n' "$rules" | awk 'NF{n++} END{print n+0}')"
  [ "$count" -eq 1 ] && [ "$rules" = "${RULE_PRIORITY}: from ${CLIENT_SUBNET} lookup ${TABLE_ID}" ]
}
prohibit_present() { ip -4 route show table "$TABLE_ID" | grep -E '^prohibit default.*metric 32760([[:space:]]|$)' >/dev/null; }

rollback_on_error() {
  rc=$?
  trap - ERR
  set +e
  if [ "$MUTATED" -eq 1 ]; then
    systemctl disable --now vps-tier-moscow-client-policy-watchdog.timer >/dev/null 2>&1 || true
    systemctl stop vps-tier-moscow-client-policy-watchdog.service >/dev/null 2>&1 || true
    rm -f "$WATCHDOG_TARGET" "$SERVICE_TARGET" "$TIMER_TARGET"
    systemctl daemon-reload >/dev/null 2>&1 || true
    rm -rf "$STATE_DIR"
  fi
  echo "ERROR: watchdog apply failed; task-owned changes reverted" >&2
  exit "$rc"
}

[ "${EUID:-$(id -u)}" -eq 0 ] || fail "run as root"
[[ "$SOURCE_HEAD" =~ ^[0-9a-f]{40}$ ]] || fail "VPS_TIER_SOURCE_HEAD must be a full lowercase commit SHA"
for cmd in awk bash cut git grep install ip rm sha256sum systemctl; do command -v "$cmd" >/dev/null 2>&1 || fail "missing command: $cmd"; done
host_ok || fail "host identity mismatch"
[ "$(git -C "$REPO_ROOT" rev-parse HEAD)" = "$SOURCE_HEAD" ] || fail "repository HEAD does not match VPS_TIER_SOURCE_HEAD"
for src in "$WATCHDOG_SOURCE" "$SERVICE_SOURCE" "$TIMER_SOURCE"; do [ -r "$src" ] || fail "managed source missing: $src"; done
bash -n "$WATCHDOG_SOURCE"
[ -r "$STAGE6_STATE" ] || fail "Stage-6 managed state missing"
[ -x "$POLICY_RUNTIME" ] || fail "policy runtime helper missing or not executable"
systemctl is-active --quiet "$POLICY_SERVICE" || fail "policy barrier service inactive"
exact_rule || fail "Stage-6 exact single policy rule must be healthy before watchdog apply"
prohibit_present || fail "Stage-6 prohibit default must be healthy before watchdog apply"
[ ! -e "$STATE_DIR" ] || fail "watchdog managed state already exists"
[ ! -e "$WATCHDOG_TARGET" ] || fail "watchdog runtime target already exists"
[ ! -e "$SERVICE_TARGET" ] || fail "watchdog service target already exists"
[ ! -e "$TIMER_TARGET" ] || fail "watchdog timer target already exists"

trap rollback_on_error ERR
MUTATED=1
install -d -o root -g root -m 0755 "$(dirname "$WATCHDOG_TARGET")"
install -o root -g root -m 0755 "$WATCHDOG_SOURCE" "$WATCHDOG_TARGET"
install -o root -g root -m 0644 "$SERVICE_SOURCE" "$SERVICE_TARGET"
install -o root -g root -m 0644 "$TIMER_SOURCE" "$TIMER_TARGET"
systemctl daemon-reload
systemctl start vps-tier-moscow-client-policy-watchdog.service
systemctl enable --now vps-tier-moscow-client-policy-watchdog.timer >/dev/null
systemctl is-enabled --quiet vps-tier-moscow-client-policy-watchdog.timer || fail "watchdog timer not enabled"
systemctl is-active --quiet vps-tier-moscow-client-policy-watchdog.timer || fail "watchdog timer not active"
exact_rule || fail "exact single policy rule missing after watchdog activation"
prohibit_present || fail "prohibit default missing after watchdog activation"

install -d -o root -g root -m 0700 "$STATE_DIR"
WATCHDOG_SHA="$(sha256sum "$WATCHDOG_TARGET" | awk '{print $1}')"
SERVICE_SHA="$(sha256sum "$SERVICE_TARGET" | awk '{print $1}')"
TIMER_SHA="$(sha256sum "$TIMER_TARGET" | awk '{print $1}')"
printf '%s\n' \
  'owner=vps-tier' \
  'status=applied' \
  "source_head=$SOURCE_HEAD" \
  "watchdog_sha256=$WATCHDOG_SHA" \
  "service_sha256=$SERVICE_SHA" \
  "timer_sha256=$TIMER_SHA" > "$STATE_FILE"
chmod 0600 "$STATE_FILE"
trap - ERR

echo "DONE: Moscow client policy watchdog applied"
echo "WATCHDOG_TIMER=active_enabled"
echo "INTERVAL=30s"
echo "RULE_10710=present_exact_single"
echo "PROHIBIT_DEFAULT=present"
echo "SECRETS_PRINTED=no"
