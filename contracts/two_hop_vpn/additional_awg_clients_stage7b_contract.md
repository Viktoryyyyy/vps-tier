# Additional AmneziaWG Clients — Stage 7B Contract

## Scope

Provision two additional independent AmneziaWG client identities on the accepted Moscow termination without changing the two-hop routing architecture.

- Windows: `10.71.0.3/32`
- Sber TV / Android client: `10.71.0.4/32`

The accepted iPhone peer `10.71.0.2/32` remains unchanged.

## Routing

The existing Stage-6 Moscow policy applies to source subnet `10.71.0.0/24`. The accepted Kazakhstan Stage-4 return route and SNAT also cover `10.71.0.0/24`. Therefore no new policy-routing, forwarding, firewall or Kazakhstan changes are required.

Each new client profile uses:

- endpoint `147.45.184.140:443`;
- DNS `1.1.1.1`;
- IPv4 `AllowedIPs=0.0.0.0/0`;
- IPv6 `AllowedIPs=::/0` for fail-closed capture;
- MTU `1280`;
- persistent keepalive `25`.

## Identity Isolation

Each device receives its own client private/public keypair and its own server peer entry. The iPhone profile must not be reused on Windows or TV.

## Secret Boundary

Private keys, AWG J/S/H parameter values and complete client profiles remain runtime-only on Moscow. They must not be committed, printed to chat, logs, GitHub issues, PRs or observed evidence.

## Runtime Outputs

- `/var/lib/vps-tier/additional-awg-clients/windows.conf`
- `/var/lib/vps-tier/additional-awg-clients/sber-tv.conf`
- `/var/lib/vps-tier/additional-awg-clients/state.env`

The profiles are root-only mode `0600` until a controlled copy is explicitly made for transfer.

## Acceptance

- server has three independent peers for `10.71.0.2/32`, `10.71.0.3/32`, `10.71.0.4/32`;
- iPhone peer remains present;
- both new profiles parse with `awg-quick strip`;
- Stage-6 services remain active;
- no Moscow NAT is added;
- no Kazakhstan mutation occurs;
- no secret material is printed.

End-to-end egress tests for Windows and TV are performed after profile import.