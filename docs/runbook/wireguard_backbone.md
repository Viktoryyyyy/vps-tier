# Moscow–Kazakhstan WireGuard Backbone

## Scope

This stage creates only the standard WireGuard server-to-server backbone:

```text
Moscow 10.70.0.1/30 <-> 10.70.0.2/30 Kazakhstan
INTERFACE=wg-backbone
UDP_PORT=51820
DEFAULT_ROUTE_CHANGE=no
FORWARDING_CHANGE=no
NAT_CHANGE=no
CLIENT_SUBNET_ROUTE=no
```

It does not yet route the client subnet, perform Kazakhstan Internet NAT, create the Moscow AmneziaWG client ingress, or generate an iPhone profile.

## Public Keys

```text
MOSCOW_PUBLIC_KEY=tfSZHDDhIcgim4s6fujmel13vSvThM1Q5EAq/lK8kDQ=
KAZAKHSTAN_PUBLIC_KEY=SXeu14QxklfRSCu7r/ePgYYPwasKobsk8jUWAsIeGhs=
```

Private keys remain server-only:

```text
/etc/wireguard/vps-tier/backbone.key
/etc/wireguard/vps-tier/backbone.pub
```

## Managed Runtime

```text
/etc/wireguard/wg-backbone.conf
wg-quick@wg-backbone.service
/var/lib/vps-tier/wireguard-backbone/<role>/
```

The generated runtime configuration contains the server-local private key and must never be committed or printed.

## Apply Order

1. Synchronize Moscow repository to the approved merged `main` SHA.
2. Copy the approved apply script to Kazakhstan.
3. Apply Kazakhstan first so UDP/51820 and the peer interface are ready.
4. Apply Moscow second. Moscow initiates the handshake and must prove ping reachability to `10.70.0.2`.
5. Verify the latest handshake and bidirectional peer reachability.

The apply script:

- binds each role to the expected public IPv4 and Ubuntu suite;
- verifies the local private key derives the approved public key;
- creates `wg-backbone` with the approved /30 address;
- enables `wg-quick@wg-backbone.service`;
- adds only two managed UFW rules per host: public UDP peer and tunnel-peer traffic;
- verifies no default-route, forwarding, IPv6-forwarding, or NAT-table change;
- verifies protected service state is unchanged;
- writes server-local non-secret evidence.

## Rollback Order

Rollback Moscow first, then Kazakhstan:

```bash
sudo bash scripts/rollback_wireguard_backbone_host.sh moscow
sudo bash /tmp/vps-tier-wg-backbone-rollback.sh kazakhstan
```

Rollback removes only the managed interface configuration, unit enablement, routes created by `wg-quick`, and the two task-owned UFW rules. It does not remove the server private keys or the installed `wireguard-tools` package.

## Acceptance

```text
MOSCOW_INTERFACE=wg-backbone_up_enabled
KAZAKHSTAN_INTERFACE=wg-backbone_up_enabled
MOSCOW_ADDRESS=10.70.0.1/30
KAZAKHSTAN_ADDRESS=10.70.0.2/30
UDP_51820=peer_restricted
HANDSHAKE=present
MOSCOW_TO_KAZAKHSTAN_PING=passed
DEFAULT_ROUTES=unchanged
FORWARDING=unchanged
NAT=unchanged
PROTECTED_SERVICES=unchanged
PRIVATE_MATERIAL_IN_GIT=none
```
