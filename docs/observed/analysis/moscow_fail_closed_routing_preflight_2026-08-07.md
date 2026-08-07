# Moscow Fail-Closed Routing — Observed Stage 6 Preflight

- Observation date: 2026-08-07
- Runtime mutation in this observation: none
- Stage 5 status: accepted before this observation
- Secrets recorded: none

## Existing Policy Routing

Observed IPv4 rules:

```text
0:      from all lookup local
32766:  from all lookup main
32767:  from all lookup default
```

Table `1071` does not exist and no `1071` registration was observed in the checked `rt_tables` paths.

```text
POLICY_TABLE_1071=unused
POLICY_PRIORITY_10710=unused
```

## Backbone Baseline

The active Moscow backbone peer still has only:

```text
AllowedIPs=10.70.0.2/32
```

The persistent backbone configuration reports the accepted baseline address, listener, peer, endpoint and keepalive. No `Table`, `PostUp`, or `PreDown` routing lifecycle directive was observed by the Stage-6 preflight query.

## Forwarding And Reverse-Path Filtering

Observed:

```text
net.ipv4.ip_forward=0
net.ipv6.conf.all.forwarding=0
net.ipv4.conf.all.rp_filter=2
net.ipv4.conf.default.rp_filter=2
net.ipv4.conf.eth0.rp_filter=2
net.ipv4.conf.awg-client.rp_filter=2
net.ipv4.conf.wg-backbone.rp_filter=2
```

The loose `rp_filter=2` baseline is compatible with the planned routed client path and must be preserved.

## UFW Baseline

UFW is active with:

```text
Default: deny incoming
Default: allow outgoing
Default routed policy: disabled/deny
```

The existing `ufw-before-forward` chain accepts `RELATED,ESTABLISHED` traffic before user-forward rules.

The Stage-6 dry-run checks passed for both planned routed rules:

```text
awg-client -> wg-backbone : allow from 10.71.0.0/24
awg-client -> eth0        : deny  from 10.71.0.0/24
```

```text
UFW_ROUTE_SYNTAX=pass
```

## Existing Client Egress State

Before Stage 6:

- no Moscow NAT rule references `10.71.0.0/24`;
- no Stage-6 policy table exists;
- no Stage-6 source rule exists;
- `ip route get 1.1.1.1 from 10.71.0.2 iif awg-client` returned `No route to host` while Moscow forwarding remained disabled.

```text
MOSCOW_CLIENT_NAT=absent
CURRENT_CLIENT_FORWARDING=blocked
```

## Preflight Verdict

```text
STAGE5_TERMINATION=ready
BACKBONE=ready
POLICY_TABLE_1071=free
POLICY_PRIORITY_10710=free
RP_FILTER=loose_2
UFW_ROUTED_DEFAULT=deny
UFW_ROUTE_SYNTAX=pass
MOSCOW_CLIENT_NAT=absent
MOSCOW_IPV4_FORWARDING=0
MOSCOW_IPV6_FORWARDING=0
STAGE6_IMPLEMENTATION=ready_for_review
```
