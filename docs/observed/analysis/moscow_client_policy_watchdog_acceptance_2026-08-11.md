# Moscow Client Policy Watchdog — Live Acceptance — 2026-08-11

## Scope

This file records non-secret runtime acceptance evidence for the Git-managed Moscow client policy watchdog introduced by PR #35.

Source main SHA applied on Moscow:

```text
50a6f214d6a5b88b27bbe7be94396dfc62cbbd31
```

## Apply Result

Observed apply output on the Moscow VPS:

```text
DONE: Moscow client policy watchdog applied
WATCHDOG_TIMER=active_enabled
INTERVAL=30s
RULE_10710=present_exact_single
PROHIBIT_DEFAULT=present
SECRETS_PRINTED=no
```

## Timer State

Observed immediately after apply:

```text
Loaded: loaded (/etc/systemd/system/vps-tier-moscow-client-policy-watchdog.timer; enabled; preset: enabled)
Active: active (waiting) since Tue 2026-08-11 10:01:36 MSK
Trigger: Tue 2026-08-11 10:03:07 MSK
Triggers: vps-tier-moscow-client-policy-watchdog.service
```

Acceptance interpretation:

```text
WATCHDOG_TIMER_LOADED=yes
WATCHDOG_TIMER_ENABLED=yes
WATCHDOG_TIMER_ACTIVE=yes
WATCHDOG_SERVICE_TRIGGER_BOUND=yes
```

## Controlled Repair Test

The exact managed source-policy rule was deliberately removed while the iPhone VPN tunnel remained enabled:

```text
10710: from 10.71.0.0/24 lookup 1071
```

No UFW rule, AWG configuration, WireGuard configuration, backbone route, NAT rule, or `prohibit default` route was changed for the test.

Observed test output:

```text
TEST_START=10:04:32
RULE_10710=deleted
WAIT_SEC=5
WAIT_SEC=10
WAIT_SEC=15
WATCHDOG_RESTORED=yes AFTER_SEC=20
1.1.1.1 from 10.71.0.2 dev wg-backbone table 1071
    cache iif awg-client
```

The watchdog restored the missing managed rule automatically after approximately 20 seconds, within the configured 30-second timer cadence.

The post-repair route lookup for the iPhone source returned to the intended Kazakhstan backbone path through routing table `1071`.

## Verdict

```text
WATCHDOG_APPLY=passed
WATCHDOG_TIMER=active_enabled
CONTROLLED_DRIFT_DETECTED=yes
CONTROLLED_DRIFT_REPAIRED=yes
REPAIR_OBSERVED_AFTER_SEC=20
POLICY_RULE_10710_RESTORED=yes
POST_REPAIR_ROUTE=wg-backbone_table_1071
MANUAL_POLICY_SERVICE_RESTART_REQUIRED=no
FAIL_CLOSED_ARCHITECTURE=preserved
SECRETS_RECORDED=no
```

## Operational Result

The failure mode observed earlier on 2026-08-11 is now covered by an automatic recovery control: if the exact managed policy rule or terminal `prohibit default` disappears while Stage 6 remains active, the watchdog invokes the existing managed policy runtime helper and restores the barrier without operator intervention.

The watchdog does not create the usable `wg-backbone` default route and does not alter UFW, NAT, AWG, or WireGuard configuration.
