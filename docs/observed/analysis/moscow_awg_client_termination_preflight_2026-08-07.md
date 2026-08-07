# Moscow AmneziaWG Client Termination — Observed Preflight

- Observation date: 2026-08-07
- Repository base SHA: `3520cbd537a5602c20ecd62f81d14742db6099ac`
- Runtime mutation in this observation: none
- Secrets recorded: none

## Toolchain

Observed on Moscow:

```text
AWG_COMMAND=/usr/bin/awg
AMNEZIAWG_MODULE=/lib/modules/6.8.0-85-generic/updates/dkms/amneziawg.ko.zst
AMNEZIAWG_MODULE_VERSION=3.0.20260805
AWG_INTERFACE_EXISTING=none
```

The previously accepted toolchain apply evidence also records `awg-quick` as present and the package/module validation as passed.

## UDP/443

The UDP/443 listener query returned no listener.

The UFW query returned no `443/udp`, `10.71.*`, or AWG-related rule.

```text
UDP_443=free_observed
AWG_UFW_CONFLICT=none_observed
```

TCP/443 is outside this stage and remains owned by the existing Nginx path.

## Moscow IPv4 State

Observed global addresses:

```text
eth0=147.45.184.140/24
wg-backbone=10.70.0.1/30
```

Observed relevant routes:

```text
default via 147.45.184.1 dev eth0
10.70.0.0/30 dev wg-backbone
147.45.184.0/24 dev eth0
```

No `10.71.0.0/24` route was present before Stage 5.

```text
CLIENT_SUBNET=10.71.0.0/24
CLIENT_SUBNET_ROUTE=absent_observed
```

## Forwarding

```text
net.ipv4.ip_forward=0
net.ipv6.conf.all.forwarding=0
```

Stage 5 must preserve both values. Client packet forwarding is intentionally deferred to Stage 6.

## Existing Managed State

The only AWG-related managed state found by the preflight search was:

```text
/var/lib/vps-tier/moscow-awg-toolchain
```

No client-ingress interface/config/key state was observed.

## Protected Services

```text
ssh.socket=active
nginx=active
postgresql=active
flowise-proxy=active
vps-backup-relay.socket=active
```

## Current Upstream Compatibility Re-check

Re-checked on 2026-08-07 against official upstream sources:

- AmneziaWG Linux kernel-module documentation still requires S1/S2/H1-H4 to match between peers and documents recommended Jc/Jmin/Jmax ranges;
- official AmneziaWG iOS App Store version 2.0.2 reports AWG 2 support;
- upstream still has open issues around empty `I1`–`I5` values in `awg-quick`/AWG 2 configurations.

Stage 5 therefore uses the broadly supported AWG parameter set `Jc`, `Jmin`, `Jmax`, `S1`, `S2`, `H1`–`H4` and deliberately does not emit `I1`–`I5`.

References:

```text
https://github.com/amnezia-vpn/amneziawg-linux-kernel-module
https://github.com/amnezia-vpn/amneziawg-tools/issues/40
https://apps.apple.com/app/amneziawg/id6478942365
```

## Preflight Verdict

```text
AWG_TOOLCHAIN=ready
UDP_443=free
CLIENT_SUBNET_CONFLICT=none_observed
IPV4_FORWARDING=0
IPV6_FORWARDING=0
PROTECTED_SERVICES=healthy
STAGE5_IMPLEMENTATION=ready_for_review
RUNTIME_MUTATION=none
```
