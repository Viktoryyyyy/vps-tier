# Kazakhstan Client Egress Stage Contract

## Scope

This contract implements Stage 4 of the two-hop VPN architecture for the approved client subnet:

```text
CLIENT_SUBNET=10.71.0.0/24
BACKBONE_INTERFACE=wg-backbone
KAZAKHSTAN_WAN_INTERFACE=enp3s0
KAZAKHSTAN_EGRESS_IPV4=194.32.142.88
```

## Required State

Kazakhstan must:

- accept `10.71.0.0/24` only from the approved Moscow WireGuard peer;
- maintain a return route for `10.71.0.0/24` through `wg-backbone`;
- allow forwarding only from that client subnet entering `wg-backbone` and leaving `enp3s0`;
- preserve established/related return traffic handling;
- apply explicit SNAT to `194.32.142.88` for that client subnet only;
- keep `net.ipv4.ip_forward=1` unchanged;
- keep IPv6 forwarding disabled;
- keep the Kazakhstan default route unchanged;
- preserve the existing backbone and protected application services.

## WireGuard Boundary

The Kazakhstan view of the Moscow peer must contain:

```text
AllowedIPs = 10.70.0.1/32, 10.71.0.0/24
```

This both authorizes packets sourced from the client subnet to arrive from the Moscow peer and provides persistent return-route ownership after `wg-quick` startup.

## NAT Boundary

The only authorized new NAT behavior is:

```text
source=10.71.0.0/24
out_interface=enp3s0
translation=SNAT_to_194.32.142.88
owner_comment=vps-tier-kz-client-egress
```

No Docker NAT rule, other source subnet, destination, port, or host traffic may be modified.

## Firewall Boundary

The only authorized new routed allow is:

```text
in_interface=wg-backbone
out_interface=enp3s0
source=10.71.0.0/24
owner_comment=vps-tier-kz-client-egress-forward
```

Return traffic relies on the already observed `RELATED,ESTABLISHED` UFW forward rule.

## Excluded

This stage does not:

- configure Moscow client termination;
- enable Moscow IPv4 forwarding;
- add Moscow policy routing;
- create an iPhone profile;
- alter DNS;
- enable IPv6 forwarding;
- change either host default route;
- prove end-to-end client Internet egress;
- modify application services or Docker networking.

## Acceptance

```text
CLIENT_SUBNET_CONFLICT=none
KZ_PEER_ALLOWED_IPS=10.70.0.1/32+10.71.0.0/24
KZ_CLIENT_RETURN_ROUTE=present
KZ_UFW_CLIENT_FORWARD=present_managed
KZ_CLIENT_SNAT=194.32.142.88_managed
DEFAULT_ROUTE_CHANGE=none
IPV4_FORWARD_CHANGE=none
IPV6_FORWARD_CHANGE=none
BACKBONE_HEALTH=preserved
PROTECTED_SERVICES=unchanged
END_TO_END_TEST=deferred
```
