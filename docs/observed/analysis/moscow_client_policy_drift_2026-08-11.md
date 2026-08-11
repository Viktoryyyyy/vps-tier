# Moscow Client Policy Drift Incident — 2026-08-11

## Scope

This file records non-secret runtime observations from a client-connectivity incident on the Moscow VPS.

No VPN private key, complete profile, AWG protected parameter, token or credential is recorded.

## Initial Client-Side Symptom

The iPhone AmneziaWG tunnel was enabled but Internet access did not work.

The question under investigation was whether the access provider had newly blocked the Moscow AmneziaWG endpoint.

## Moscow AWG And Backbone Observation

Observed on Moscow:

```text
awg-quick@awg-client=active
wg-quick@wg-backbone=active
udp/443=listening
```

Multiple AWG peers had recent handshakes. The iPhone peer at `10.71.0.2/32` continued sending traffic to Moscow; AWG receive counters increased.

The Moscow-Kazakhstan backbone remained healthy:

```text
wg-backbone handshake=present
ping 10.70.0.2=3/3 passed
packet_loss=0%
```

Conclusion: the incident was not a global block of Moscow UDP/443 and was not a backbone outage.

## Decrypted Client Traffic Observation

A bounded packet capture on Moscow showed decrypted client DNS traffic arriving on `awg-client`, including requests from `10.71.0.2` to `1.1.1.1` for domains such as ChatGPT, Google and YouTube.

Only `awg-client In` traffic was observed in that capture window; no corresponding forwarding through `wg-backbone` was observed.

Conclusion: client packets reached and were decrypted by Moscow, but forwarding policy was not selecting the backbone path.

## Routing Drift Found

Observed forwarding state:

```text
net.ipv4.ip_forward = 1
net.ipv6.conf.all.forwarding = 0
```

The expected Stage-6 policy rule was absent:

```text
10710: from 10.71.0.0/24 lookup 1071
```

Table `1071` still contained the usable backbone route:

```text
default dev wg-backbone scope link metric 10
```

A route lookup for the iPhone source instead resolved through Moscow public egress:

```text
1.1.1.1 from 10.71.0.2 via 147.45.184.1 dev eth0
```

The Stage-6 UFW boundary remained present:

```text
DENY  awg-client -> eth0        from 10.71.0.0/24
ALLOW awg-client -> wg-backbone from 10.71.0.0/24
```

This explains the user-visible failure: without the policy rule Linux selected the Moscow main route, but UFW correctly denied that unauthorized fallback. The architecture therefore failed closed rather than leaking client traffic through Moscow.

## Systemd Observation

The policy unit reported:

```text
vps-tier-moscow-client-policy.service=active (exited)
started=2026-08-07 17:53:47 MSK
main process exit=0/SUCCESS
```

This is consistent with its managed `Type=oneshot` plus `RemainAfterExit=yes` design. Systemd tracks the successful one-shot invocation, not the continued existence of the kernel rule it created.

## Recovery

The managed policy service was restarted.

Immediately afterward the expected policy rule returned:

```text
10710: from 10.71.0.0/24 lookup 1071
```

The route lookup returned to the intended path:

```text
1.1.1.1 from 10.71.0.2 dev wg-backbone table 1071
```

The user then confirmed that iPhone Internet access worked again.

## Verdict

```text
MOSCOW_AWG_ENDPOINT_BLOCKED=no_evidence
AWG_UDP443=working
MOSCOW_KZ_BACKBONE=healthy
CLIENT_PACKETS_REACHED_MOSCOW=yes
STAGE6_POLICY_RULE_DRIFT=confirmed
UFW_NO_FALLBACK=worked_as_designed
MOSCOW_EGRESS_LEAK=not_observed
MANAGED_POLICY_RESTART=recovered_connectivity
ROOT_CAUSE_OF_RULE_REMOVAL=not_attributed
```

## Follow-Up

Add a Git-managed watchdog that periodically verifies the exact Stage-6 policy rule and terminal `prohibit default`, repairing only through the existing managed Stage-6 runtime helper when drift is detected.
