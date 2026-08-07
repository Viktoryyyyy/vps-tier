# WireGuard Backbone — Two-Host Runtime Acceptance

Date: 2026-08-07

## Source

- Repository: `Viktoryyyyy/vps-tier`
- Applied Git HEAD on both hosts: `a2760ba941360c9246e5f187a890178850c654da`
- Interface: `wg-backbone`
- Backbone subnet: `10.70.0.0/30`

This evidence records the post-apply read-only acceptance observed from the Moscow host and the Kazakhstan host. No private key material is recorded.

## Moscow

- Public IPv4: `147.45.184.140`
- `wg-quick@wg-backbone`: active
- `wg-quick@wg-backbone`: enabled
- Interface address: `10.70.0.1/30`
- Connected route: `10.70.0.0/30 dev wg-backbone`
- Peer public key observed: `SXeu14QxklfRSCu7r/ePgYYPwasKobsk8jUWAsIeGhs=`
- Latest handshake epoch observed: `1786089972` (`2026-08-07T08:06:12Z`)
- Ping to `10.70.0.2`: 3/3 replies, 0% packet loss
- RTT: min/avg/max `55.126/57.147/58.274 ms`
- Default route: `default via 147.45.184.1 dev eth0 ...`
- IPv4 forwarding: `0`
- IPv6 forwarding: `0`
- UFW public rule: UDP/51820 allowed only from `194.32.142.88`
- UFW tunnel rule: `10.70.0.2` to local `10.70.0.1` on `wg-backbone`

Apply evidence reported:

- default route changed: no
- IPv4 forwarding changed: no
- IPv6 forwarding changed: no
- NAT table changed: no
- protected unit state changed: no
- ping status: passed
- handshake status: passed
- backup set: `/var/backups/vps-tier/wireguard-backbone/moscow/apply/20260806T173155Z`

## Kazakhstan

- Public IPv4: `194.32.142.88`
- `wg-quick@wg-backbone`: active
- `wg-quick@wg-backbone`: enabled
- Interface address: `10.70.0.2/30`
- Connected route: `10.70.0.0/30 dev wg-backbone`
- Peer public key observed: `tfSZHDDhIcgim4s6fujmel13vSvThM1Q5EAq/lK8kDQ=`
- Latest handshake epoch observed: `1786089972` (`2026-08-07T08:06:12Z`)
- Ping to `10.70.0.1`: 3/3 replies, 0% packet loss
- RTT: min/avg/max `55.169/55.216/55.244 ms`
- Default route: `default via 194.32.142.1 dev enp3s0 proto static`
- IPv4 forwarding: `1`
- IPv6 forwarding: `0`
- UFW public rule: UDP/51820 allowed only from `147.45.184.140`
- UFW tunnel rule: `10.70.0.1` to local `10.70.0.2` on `wg-backbone`

Apply evidence reported:

- default route changed: no
- IPv4 forwarding changed: no
- IPv6 forwarding changed: no
- NAT table changed: no
- protected unit state changed: no
- ping status during KZ-first apply: deferred
- handshake status during KZ-first apply: deferred
- backup set: `/var/backups/vps-tier/wireguard-backbone/kazakhstan/apply/20260806T172650Z`

The later two-host acceptance proves both ping and a current WireGuard handshake from each side.

## Acceptance

Status: `ACCEPTED`

The standard WireGuard Moscow↔Kazakhstan backbone is operational in both directions. The observed state satisfies the backbone stage boundaries: no default-route change, no new forwarding change on Moscow, no IPv6 forwarding, and no backbone-stage NAT mutation.

The next dependent stage may configure Kazakhstan forwarding/SNAT for the future client traffic path. That stage is intentionally separate from this backbone acceptance.
