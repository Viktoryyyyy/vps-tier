# Kazakhstan Client Egress Forwarding + SNAT

## Purpose

Prepares Kazakhstan to receive the approved client subnet `10.71.0.0/24` from Moscow over `wg-backbone` and send that traffic to the Internet with the Kazakhstan public IPv4 `194.32.142.88`.

This is Stage 4 of `contracts/two_hop_vpn/architecture_contract.md`.

## Observed Preconditions

Observed on Kazakhstan before implementation:

- `wg-backbone` is active and enabled at `10.70.0.2/30`;
- Moscow peer is `10.70.0.1/32`;
- `10.71.0.0/24` is absent from host addresses, routes, Docker networks, WireGuard AllowedIPs, UFW rules and NAT;
- Docker networks are `172.17.0.0/16`, `172.18.0.0/16`, and `172.19.0.0/16`;
- `net.ipv4.ip_forward=1` already;
- IPv6 forwarding remains `0`;
- `rp_filter=2` on all, `enp3s0`, and `wg-backbone`;
- UFW is active and routed traffic defaults to deny;
- `ufw-before-forward` accepts `RELATED,ESTABLISHED` return traffic;
- existing NAT is Docker-only.

## Managed Changes

The apply script performs only these client-egress changes on Kazakhstan:

1. Extends the Moscow WireGuard peer AllowedIPs from `10.70.0.1/32` to `10.70.0.1/32, 10.71.0.0/24` in both runtime and `/etc/wireguard/wg-backbone.conf`.
2. Adds runtime return route `10.71.0.0/24 dev wg-backbone`; persistence comes from the WireGuard AllowedIPs configuration.
3. Adds one UFW routed allow from `10.71.0.0/24`, entering `wg-backbone`, exiting `enp3s0`.
4. Adds one explicit SNAT rule for `10.71.0.0/24` through `enp3s0` to `194.32.142.88`.
5. Adds `PostUp`/`PreDown` lines to the existing WireGuard config so the owned SNAT rule follows the backbone lifecycle.

No default route, sysctl, IPv6, DNS, Docker, Nginx, Xray, Hysteria2, n8n, Flowise, cloudflared, or SSH configuration is changed.

## Safety Gates

Apply stops before mutation unless:

- exact Kazakhstan host identity and Ubuntu Jammy are confirmed;
- the managed backbone state exists and `wg-quick@wg-backbone` is active/enabled;
- the current WireGuard config is still at the approved Stage-3 baseline;
- the client subnet is unused;
- IPv4 forwarding is already `1` and IPv6 forwarding is `0`;
- rp_filter remains loose (`2`);
- UFW is active and its established-return rule is present;
- required protected services are active.

The apply captures the existing WireGuard config, NAT table, UFW status, default route, and protected-unit state before mutation. On any failure after mutation begins, task-owned changes are reverted.

## Persistence

The client return route is reconstructed by `wg-quick` from the peer AllowedIPs on backbone startup.

The SNAT rule is reconstructed by the managed `PostUp` command and removed by the managed `PreDown` command. Both commands operate only on the exact rule carrying comment `vps-tier-kz-client-egress`.

The UFW routed allow persists through UFW's managed rule store.

## Apply Sequence

After the implementation PR is merged:

1. synchronize the Moscow working copy to the exact merged `main`;
2. copy the exact apply and rollback scripts to Kazakhstan `/tmp`;
3. launch the apply script through a detached transient systemd unit with `VPS_TIER_SOURCE_HEAD` equal to the merged Git SHA;
4. inspect the unit result, journal, managed state, route, WireGuard AllowedIPs, UFW rule and SNAT rule;
5. verify the Moscow↔Kazakhstan backbone still pings and handshakes;
6. record post-apply evidence in Git.

End-to-end Internet egress from `10.71.0.0/24` is intentionally deferred until Moscow client termination/policy routing exists.

## Rollback

Use `scripts/rollback_kz_client_egress.sh` on Kazakhstan.

Rollback is fail-closed: it refuses to restore the prior WireGuard config if the managed config has diverged since this stage. A successful rollback removes only the task-owned client route, peer AllowedIPs extension, UFW routed allow, and SNAT rule while preserving the backbone.

## Acceptance

Stage 4 is accepted when:

```text
KZ_CLIENT_SUBNET_ALLOWED_FROM_MOSCOW=yes
KZ_RETURN_ROUTE=10.71.0.0/24_via_wg-backbone
KZ_UFW_FORWARD=managed
KZ_SNAT=194.32.142.88
KZ_IPV4_FORWARDING=1_unchanged
KZ_IPV6_FORWARDING=0_unchanged
KZ_DEFAULT_ROUTE=unchanged
BACKBONE=healthy
PROTECTED_SERVICES=unchanged
END_TO_END_CLIENT_EGRESS=deferred
SECRETS_IN_GIT=none
```
