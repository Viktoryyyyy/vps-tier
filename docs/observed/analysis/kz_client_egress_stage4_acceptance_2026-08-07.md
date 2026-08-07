# Kazakhstan Client Egress Stage 4 — Runtime Acceptance

- Observation date: 2026-08-07
- Applied source Git HEAD: `7fa98bdf2d56ce7dae37a53a1a86741d9816e72d`
- Runtime mutation in this evidence task: none
- Secrets recorded: none

## Verdict

```text
STAGE4_STATUS=accepted
FORWARDING_PERSISTENCE=passed
CLIENT_SUBNET=10.71.0.0/24
KZ_RETURN_ROUTE=passed
KZ_UFW_FORWARD=passed
KZ_SNAT=passed
BACKBONE_BIDIRECTIONAL=passed
KZ_PROTECTED_SERVICES=passed
END_TO_END_CLIENT_EGRESS=deferred
```

End-to-end client Internet egress remains intentionally deferred until Moscow client termination and policy routing are implemented.

## Managed State

Kazakhstan reported managed state for both dependent Stage-4 components.

Forwarding persistence:

```text
owner=vps-tier
source_head=7fa98bdf2d56ce7dae37a53a1a86741d9816e72d
applied_at_utc=20260807T085214Z
sysctl_file=/etc/sysctl.d/99-vps-tier-kz-client-egress.conf
ipv4_before=1
ipv6_before=0
```

Client egress:

```text
owner=vps-tier
source_head=7fa98bdf2d56ce7dae37a53a1a86741d9816e72d
applied_at_utc=20260807T085215Z
wg_interface=wg-backbone
wan_interface=enp3s0
client_subnet=10.71.0.0/24
persistent_allowed_ips=yes
return_route=yes
ufw_forward_rule=yes
snat_rule=yes
```

## Forwarding Persistence

Observed runtime:

```text
net.ipv4.ip_forward = 1
net.ipv6.conf.all.forwarding = 0
```

Observed managed persistence file:

```text
/etc/sysctl.d/99-vps-tier-kz-client-egress.conf
net.ipv4.ip_forward = 1
net.ipv6.conf.all.forwarding = 0
```

The forwarding-persistence apply evidence reports that no pre-existing persistent assignments were present and runtime values remained `1/0` before and after apply.

## WireGuard And Return Route

Observed Kazakhstan peer AllowedIPs:

```text
10.70.0.1/32 10.71.0.0/24
```

Observed client return route:

```text
10.71.0.0/24 dev wg-backbone scope link
```

This confirms Kazakhstan can route return traffic for the client subnet through the Moscow backbone peer.

## Firewall And NAT

Observed managed UFW routed allow:

```text
ALLOW FWD from 10.71.0.0/24 on wg-backbone to enp3s0
comment=vps-tier-kz-client-egress-forward
```

Observed managed SNAT rule:

```text
POSTROUTING source=10.71.0.0/24 out=enp3s0
comment=vps-tier-kz-client-egress
SNAT to 194.32.142.88
```

The apply evidence reports no unexpected NAT mutation outside the owned SNAT rule and no default-route change.

## Backbone Health

Kazakhstan to Moscow:

```text
ping 10.70.0.1
3 transmitted, 3 received, 0% packet loss
WireGuard latest-handshake present
```

Moscow to Kazakhstan:

```text
ping 10.70.0.2
3 transmitted, 3 received, 0% packet loss
WireGuard latest-handshake present
```

The observed handshake timestamp was present and identical from both sides during the acceptance observation.

## Protected Kazakhstan Services

Observed after Stage 4:

```text
ssh=active
nginx=active
docker=active
xray=active
hysteria-server=active
cloudflared=active
```

No protected-service failure was observed.

## Apply Evidence Summary

Server-local Stage-4 evidence reported:

```text
FORWARDING_RUNTIME_CHANGE=none
IPV4_FORWARDING=1
IPV6_FORWARDING=0
PERSISTENT_RETURN_ROUTE=yes
UFW_ROUTED_ALLOW=yes
EXPLICIT_SNAT=194.32.142.88
SNAT_PERSISTENCE=wg-quick_PostUp_PreDown
DEFAULT_ROUTE_CHANGE=no
UNEXPECTED_NAT_MUTATION=no
BACKBONE_PING_HANDSHAKE=passed
PROTECTED_UNIT_STATE_CHANGE=no
SECRETS_RECORDED=no
```

## Acceptance Decision

Stage 4 of `contracts/two_hop_vpn/architecture_contract.md` is accepted.

Kazakhstan is now prepared to receive traffic sourced from `10.71.0.0/24` over `wg-backbone` and egress it through `enp3s0` using source IPv4 `194.32.142.88`.

The next architecture stage is Moscow client termination. Moscow client forwarding, policy routing, fail-closed controls, DNS-path validation, and end-to-end public-egress validation are not claimed by this evidence.