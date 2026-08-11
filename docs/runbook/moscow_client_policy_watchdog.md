# Moscow Client Policy Watchdog

## Purpose

This runbook adds automatic repair for the Moscow Stage-6 fail-closed policy barrier.

The existing `vps-tier-moscow-client-policy.service` is intentionally `Type=oneshot` with `RemainAfterExit=yes`. It installs the policy rule and fail-closed `prohibit default`, then systemd keeps the unit in `active (exited)` state. That status does not prove that the kernel rule still exists later.

On 2026-08-11 the service remained `active (exited)` while the managed policy rule had disappeared. The UFW no-fallback rule correctly blocked client traffic from using Moscow public egress, so client Internet failed closed rather than leaking through Moscow.

The watchdog closes that observability/recovery gap without changing the two-hop architecture.

## State Under Watch

Required Stage-6 barrier:

```text
10710: from 10.71.0.0/24 lookup 1071
```

Required terminal route in table `1071`:

```text
prohibit default metric 32760
```

Healthy table `1071` normally also contains:

```text
default dev wg-backbone metric 10
```

The usable `wg-backbone` default is owned by the backbone lifecycle and is deliberately not created by this watchdog. If the backbone is down, only the `prohibit default` barrier should remain.

## Repair Behavior

Every 30 seconds the timer starts a one-shot checker.

If both the managed rule and `prohibit default` exist, the checker exits successfully without mutation and without application-level journal output. This avoids routine healthy-state log growth.

If either managed element is missing, the checker calls the already-managed Stage-6 runtime helper:

```text
/usr/local/libexec/vps-tier/moscow-client-policy-runtime up
```

That helper is idempotent for the approved rule and route. It refuses to overwrite policy priority `10710` when that priority is occupied by a different rule.

After repair the checker requires both managed elements to be present and records bounded journal output:

```text
POLICY_WATCHDOG=repair_required
POLICY_WATCHDOG=repaired
RULE_10710=restored
PROHIBIT_DEFAULT=restored
```

No keys, profiles, tokens or other secrets are read or printed.

## Managed Files

Repository sources:

```text
scripts/moscow_client_policy_watchdog.sh
scripts/apply_moscow_client_policy_watchdog.sh
scripts/rollback_moscow_client_policy_watchdog.sh
templates/systemd/vps-tier-moscow-client-policy-watchdog.service
templates/systemd/vps-tier-moscow-client-policy-watchdog.timer
```

Runtime targets on Moscow:

```text
/usr/local/libexec/vps-tier/moscow-client-policy-watchdog
/etc/systemd/system/vps-tier-moscow-client-policy-watchdog.service
/etc/systemd/system/vps-tier-moscow-client-policy-watchdog.timer
/var/lib/vps-tier/moscow-client-policy-watchdog/state.env
```

## Timer

The timer is monotonic and runs while the host is up:

```text
OnBootSec=30s
OnUnitActiveSec=30s
AccuracySec=5s
```

The watchdog service is ordered after `vps-tier-moscow-client-policy.service`, but deliberately does not `Require=` it. The checker itself refuses repair when the Stage-6 policy service is inactive. This prevents the watchdog from re-starting the policy barrier during a controlled Stage-6 rollback.

## Apply

After this change is merged to `main`, synchronize the Moscow repository to the exact merged SHA and execute:

```text
sudo env VPS_TIER_SOURCE_HEAD=<exact-merged-main-sha> bash scripts/apply_moscow_client_policy_watchdog.sh
```

The apply stops before mutation unless:

- the host is the Moscow VPS `147.45.184.140`;
- repository HEAD exactly equals `VPS_TIER_SOURCE_HEAD`;
- Stage-6 managed state exists;
- the existing policy runtime helper exists and is executable;
- `vps-tier-moscow-client-policy.service` is active;
- policy rule `10710` is currently healthy;
- `prohibit default metric 32760` is currently healthy;
- no watchdog-managed runtime files or state already exist.

The apply installs only watchdog-owned files, performs a one-time check, enables the timer and verifies the Stage-6 barrier remains intact.

## Acceptance

Required post-apply state:

```text
vps-tier-moscow-client-policy-watchdog.timer=active_enabled
watchdog interval=30s
10710 from 10.71.0.0/24 lookup 1071=present
prohibit default metric 32760=present
existing Stage-6 policy service=preserved
Moscow UFW fail-closed rules=unchanged
Moscow NAT=unchanged
```

Recommended controlled repair test after apply:

1. Confirm the client tunnel works.
2. Delete only the exact managed policy rule `10710` as a controlled test.
3. Do not alter UFW or the `prohibit default` route.
4. Observe the watchdog restore the rule within approximately 30-35 seconds.
5. Confirm the client recovers and still exits through Kazakhstan `194.32.142.88`.
6. Record the test in `docs/observed/analysis/`.

The controlled deletion is destructive to client connectivity for the test window and must be explicitly authorized before execution.

## Rollback

Use:

```text
sudo bash scripts/rollback_moscow_client_policy_watchdog.sh
```

Rollback removes only watchdog-owned files and state. It first verifies their recorded SHA-256 hashes and refuses to remove diverged files.

Rollback does not remove or alter:

- Stage-6 policy rule;
- Stage-6 `prohibit default`;
- table `1071` usable backbone route;
- UFW forwarding rules;
- AWG configuration;
- WireGuard backbone configuration.

Before any future full Stage-6 rollback, remove this watchdog first with its managed rollback script. This prevents an orphaned timer and makes rollback ownership explicit.

## Root Cause Boundary

The 2026-08-11 incident proves that the kernel policy rule disappeared while the one-shot systemd service remained `active (exited)`. It does not prove what external action removed the rule. Linux policy-rule mutations are not automatically journaled with attribution. The watchdog is therefore a resilience control, not a claim that the original remover has been identified.
