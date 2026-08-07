# Kazakhstan Client Egress — Observed Preflight

- Observation date: 2026-08-07
- Runtime mutation in this observation: none
- Secrets recorded: none

## Address And Route State

Observed IPv4 networks on Kazakhstan:

```text
194.32.142.0/24  enp3s0
10.70.0.0/30     wg-backbone
172.17.0.0/16    docker0
172.18.0.0/16    Docker bridge
172.19.0.0/16    Docker bridge
```

The planned client subnet `10.71.0.0/24` was absent from host addresses and all routing tables.

The default route remained:

```text
default via 194.32.142.1 dev enp3s0
```

## Docker Networks

Observed Docker subnets:

```text
172.17.0.0/16
172.18.0.0/16
172.19.0.0/16
```

No overlap with `10.71.0.0/24` was observed.

## Forwarding And Reverse-Path Filtering

```text
net.ipv4.ip_forward=1
net.ipv6.conf.all.forwarding=0
net.ipv4.conf.all.rp_filter=2
net.ipv4.conf.enp3s0.rp_filter=2
net.ipv4.conf.wg-backbone.rp_filter=2
```

Stage 4 therefore does not need to change forwarding sysctls.

## WireGuard

Kazakhstan currently authorizes only the Moscow backbone address for the Moscow peer:

```text
10.70.0.1/32
```

`10.71.0.0/24` was not present in the peer AllowedIPs at observation time.

## UFW

UFW was active. Existing managed backbone rules were:

```text
51820/udp from 147.45.184.140
10.70.0.2 on wg-backbone from 10.70.0.1
```

No UFW rule referenced `10.71.0.0/24`.

The filter table contained the existing return-traffic rule:

```text
ufw-before-forward ... RELATED,ESTABLISHED ... ACCEPT
```

## NAT

No NAT rule referenced `10.71.0.0/24` or the planned owner marker `vps-tier-kz-client-egress`.

Existing NAT remained application/Docker state only.

## Preflight Verdict

```text
CLIENT_SUBNET=10.71.0.0/24
CLIENT_SUBNET_CONFLICT=none_observed
KZ_IPV4_FORWARDING=ready_existing_1
KZ_IPV6_FORWARDING=disabled_existing_0
KZ_RP_FILTER=loose_2
KZ_WG_ALLOWED_IPS_EXTENSION=required
KZ_RETURN_ROUTE=required
KZ_UFW_FORWARD_RULE=required
KZ_SNAT_RULE=required
RUNTIME_MUTATION=none
```
