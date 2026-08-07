# Moscow Fail-Closed Client Routing — Stage 6 Contract

## Scope

Stage 6 connects the already accepted Moscow AmneziaWG client subnet to the already accepted Moscow↔Kazakhstan WireGuard backbone without permitting fallback through Moscow public egress.

```text
CLIENT_SUBNET=10.71.0.0/24
CLIENT_INTERFACE=awg-client
BACKBONE_INTERFACE=wg-backbone
MOSCOW_PUBLIC_INTERFACE=eth0
POLICY_TABLE=1071
POLICY_RULE_PRIORITY=10710
```

## Required Data Path

```text
10.71.0.0/24 -> awg-client -> policy table 1071 -> wg-backbone -> Kazakhstan
```

Moscow must never SNAT client traffic and must never forward the client subnet through `eth0`.

## Policy Routing Contract

Stage 6 owns one source-policy rule:

```text
priority=10710
from=10.71.0.0/24
lookup=1071
```

Table `1071` must contain both:

```text
default dev wg-backbone metric 10
prohibit default metric 32760
```

The unicast default is usable only while the backbone interface exists. The lower-preference `prohibit default` remains as the terminal fail-closed result when the usable backbone route disappears. The source-policy rule must remain installed independently of backbone interface lifecycle so lookup cannot continue to Moscow's `main` table after a backbone outage.

No route is added to Moscow's `main` table and Moscow's ordinary default route remains unchanged.

## WireGuard Cryptokey Routing Contract

The Moscow view of the Kazakhstan backbone peer changes from:

```text
AllowedIPs = 10.70.0.2/32
```

to:

```text
AllowedIPs = 0.0.0.0/0
```

This is required both for outbound client Internet destinations and for inbound Internet reply source addresses arriving from Kazakhstan after Kazakhstan conntrack/NAT processing.

Because `0.0.0.0/0` must not cause `wg-quick` to mutate Moscow's normal routing table, the persistent backbone configuration must also contain:

```text
Table = off
```

The Stage-6 configuration owns only a policy-table lifecycle hook for the usable backbone default route. It does not replace the host default route.

## Firewall Contract

UFW routed default remains deny/disabled.

Stage 6 adds exactly two task-owned routed rules:

```text
DENY  in=awg-client out=eth0        from=10.71.0.0/24
ALLOW in=awg-client out=wg-backbone from=10.71.0.0/24
```

The explicit `eth0` deny is defense in depth against any policy-routing regression. Other forwarding remains denied by the existing UFW routed default. Return traffic uses the already observed `RELATED,ESTABLISHED` rule.

No broad reverse routed allow is authorized.

## Forwarding Contract

Only after the policy barrier and firewall controls are installed may Moscow IPv4 forwarding change from `0` to `1`.

Stage 6 persists:

```text
net.ipv4.ip_forward=1
net.ipv6.conf.all.forwarding=0
```

IPv6 forwarding remains disabled. Current loose reverse-path filtering (`rp_filter=2`) on `all`, `default`, `eth0`, `awg-client`, and `wg-backbone` is a required precondition and is not modified by this stage.

## Boot Fail-Closed Contract

A managed policy-barrier systemd unit installs the source rule and terminal `prohibit default` independently of the backbone interface.

The AWG client unit gains a systemd dependency requiring both:

- active UFW startup handling;
- successful policy-barrier installation.

Therefore the client termination must not become available at boot before the fail-closed policy barrier is present. If the backbone comes up later, its `PostUp` adds only the usable table-1071 route. If the backbone is absent, the policy rule terminates at `prohibit default` rather than falling through to Moscow `eth0`.

## NAT Boundary

Moscow client NAT remains forbidden:

```text
MOSCOW_CLIENT_NAT=absent
```

Kazakhstan remains the only approved Internet source-NAT host for `10.71.0.0/24`.

## Protected Runtime Scope

Stage 6 must preserve:

```text
ssh.socket
nginx.service
postgresql.service
flowise-proxy.service
vps-backup-relay.socket
awg-quick@awg-client.service
wg-quick@wg-backbone.service
```

It must not modify application configuration, DNS, Docker, Kazakhstan application services, or either host's normal default route.

## Apply Order

Fail-closed ordering is mandatory:

1. validate the exact Stage-5 and backbone baseline;
2. snapshot configuration, NAT, main routes and protected services;
3. install the persistent policy barrier and AWG boot dependency;
4. widen the backbone peer cryptokey route and install table-1071 usable route;
5. add explicit UFW no-fallback deny and backbone allow;
6. persist forwarding configuration;
7. enable IPv4 forwarding last;
8. verify policy lookup, NAT absence, main-route preservation, backbone health and protected services.

## Rollback Order

Rollback closes IPv4 forwarding first. Only then may it remove UFW/policy barriers, restore the Stage-5 WireGuard AllowedIPs/configuration and remove Stage-6 persistence artifacts.

Rollback must preserve the Stage-5 AWG termination and the standard WireGuard backbone.

## Acceptance

```text
POLICY_RULE=10710_from_10.71.0.0/24_lookup_1071
POLICY_USABLE_DEFAULT=wg-backbone
POLICY_FAIL_CLOSED_DEFAULT=prohibit
BACKBONE_ALLOWED_IPS=0.0.0.0/0
WG_QUICK_TABLE=off
UFW_CLIENT_TO_BACKBONE=managed_allow
UFW_CLIENT_TO_ETH0=managed_deny
MOSCOW_IPV4_FORWARDING=1_managed
MOSCOW_IPV6_FORWARDING=0
MOSCOW_DEFAULT_ROUTE=unchanged
MOSCOW_MAIN_TABLE=unchanged
MOSCOW_CLIENT_NAT=absent
BACKBONE=healthy
PROTECTED_SERVICES=unchanged
END_TO_END_CLIENT_TEST=deferred_until_profile
```
