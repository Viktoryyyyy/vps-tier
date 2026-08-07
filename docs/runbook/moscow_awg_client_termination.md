# Moscow AmneziaWG Client Termination — Stage 5 Runbook

## Purpose

Creates the iPhone-facing AmneziaWG 2 endpoint on Moscow while deliberately keeping routed client Internet access disabled until Stage 6.

```text
interface=awg-client
server_address=10.71.0.1/24
first_client_address=10.71.0.2/32
listen=147.45.184.140:443/udp
mtu=1280
```

## Preconditions

The apply script fails closed unless all of the following remain true:

- Moscow host identity is `147.45.184.140`, Ubuntu Noble amd64;
- current managed AWG toolchain state exists;
- `awg`, `awg-quick`, the `amneziawg` module, and `awg-quick@.service` are available;
- module version remains the observed `3.0.20260805` baseline;
- managed standard-WireGuard backbone state exists and its unit is active;
- UDP/443 is free;
- no AWG client interface/config/material/state exists;
- no conflicting client-subnet route/address exists;
- UFW is active with no unmanaged Stage-5-related rule;
- Moscow IPv4 and IPv6 forwarding both remain `0`;
- protected services are active.

## Runtime Material

The script generates all client-ingress material on Moscow under root-only paths:

```text
/etc/amnezia/amneziawg/awg-client.conf
/etc/amnezia/amneziawg/vps-tier/awg-client/server.key
/etc/amnezia/amneziawg/vps-tier/awg-client/server.pub
/etc/amnezia/amneziawg/vps-tier/awg-client/iphone.key
/etc/amnezia/amneziawg/vps-tier/awg-client/iphone.pub
/etc/amnezia/amneziawg/vps-tier/awg-client/params.env
```

Private/profile-bearing values must never be printed, pasted into chat, or committed.

The first-client private key is generated now so the later client-profile stage can render the exact iPhone profile without changing the server peer identity.

## AWG Parameters

The apply generates one compatibility-oriented AWG parameter set at runtime:

- Jc random 4–12;
- Jmin 8;
- Jmax 80;
- S1/S2 random within the upstream recommended range;
- four unique H1–H4 values in the upstream recommended range.

`I1`–`I5` are not used in this Stage-5 profile due to current upstream compatibility issues around empty values.

## Managed Firewall Change

Exactly one UFW IPv4 rule is added:

```text
allow udp/443 to 147.45.184.140
comment=vps-tier-awg-client-ingress
```

No forwarding rule is added.

## Apply Sequence

After the implementation PR is reviewed and merged:

1. synchronize the Moscow repository to the exact merged `main` SHA;
2. prove the working tree is clean;
3. launch `scripts/apply_moscow_awg_client_termination.sh` through a unique detached `systemd-run` unit with `VPS_TIER_SOURCE_HEAD=<merged-main-sha>`;
4. do not rerun after a terminal disconnect; inspect the existing unit and journal first;
5. accept only from runtime evidence.

## Runtime Acceptance

Verify without printing the config, private keys, or parameter file contents:

```text
awg-quick@awg-client=active_enabled
awg-client_address=10.71.0.1/24
awg-client_udp_port=443
peer_allowed_ip=10.71.0.2/32
managed_ufw_marker=vps-tier-awg-client-ingress
ipv4_forward=0
ipv6_forward=0
default_route=unchanged
moscow_nat=unchanged
wg-backbone=healthy
protected_services=healthy
```

A client handshake is not required until the iPhone profile is generated/imported.

## Stage Boundary

Stage 5 does not authorize client packet forwarding.

Because Moscow `net.ipv4.ip_forward=0`, a later imported client profile may establish an AWG tunnel but cannot use Moscow's ordinary Internet default route. Stage 6 separately implements controlled client-to-backbone forwarding and fail-closed policy routing.

## Rollback

Use:

```text
scripts/rollback_moscow_awg_client_termination.sh
```

Rollback removes only task-owned AWG interface/config/material and the managed UDP/443 UFW rule. It preserves the installed AWG toolchain and standard WireGuard backbone.

Rollback refuses to delete a present AWG config when its SHA-256 differs from the managed applied config, preventing destruction of later manual or managed changes.

## Evidence

After successful runtime acceptance, record non-secret evidence in a separate evidence PR under:

```text
docs/observed/analysis/
```

Do not record private keys, complete client configuration, QR payload, or AWG parameter values.
