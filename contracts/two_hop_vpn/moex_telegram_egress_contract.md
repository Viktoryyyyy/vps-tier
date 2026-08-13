# MOEX Telegram Private Egress Contract

## Status And Scope

This contract defines a narrow application-egress path for MOEX Bot Telegram delivery when the Moscow VPS cannot reach `api.telegram.org` directly.

The approved data path is:

```text
MOEX Bot on Moscow
  -> HTTPS proxy request over existing wg-backbone
  -> private CONNECT relay on Kazakhstan 10.70.0.2
  -> api.telegram.org:443
  -> Internet egress from Kazakhstan 194.32.142.88
```

This path is independent from the existing client full-tunnel path:

```text
10.71.0.0/24 -> awg-client -> policy table 1071 -> wg-backbone -> Kazakhstan SNAT -> Internet
```

The client path, its fail-closed controls, and its NAT contract must remain unchanged.

## Fixed Identities

```text
MOSCOW_PUBLIC_IPV4=147.45.184.140
MOSCOW_BACKBONE_IPV4=10.70.0.1
KAZAKHSTAN_PUBLIC_IPV4=194.32.142.88
KAZAKHSTAN_BACKBONE_IPV4=10.70.0.2
BACKBONE_INTERFACE=wg-backbone
RELAY_LISTEN_IPV4=10.70.0.2
RELAY_LISTEN_PORT=18080/tcp
ALLOWED_RELAY_PEER=10.70.0.1
ALLOWED_CONNECT_TARGET=api.telegram.org:443
```

## Design Choice

The relay is a minimal HTTP CONNECT proxy dedicated to one target only.

It must:

- bind only to Kazakhstan backbone address `10.70.0.2`;
- accept TCP clients only from Moscow backbone address `10.70.0.1`;
- accept only HTTP `CONNECT api.telegram.org:443`;
- reject every other method, host, and port;
- resolve `api.telegram.org` on Kazakhstan;
- open the upstream TLS TCP connection from the Kazakhstan host;
- tunnel bytes without terminating TLS;
- never inspect or log the Telegram bot token, request path, message body, or HTTPS payload;
- cap request-header size and connection setup time;
- run as a dedicated hardened systemd service;
- require the existing `wg-backbone` service.

The MOEX application will use the relay as an HTTPS proxy. The TLS session remains end-to-end between the MOEX process and `api.telegram.org`; the relay sees only the CONNECT target.

## Why Destination Routing Is Not Used

No route for Telegram public IPs may be added to Moscow `main` or policy table `1071`.

Reasons:

- Telegram DNS results may change;
- table `1071` is owned by the client fail-closed path;
- Kazakhstan Stage-4 forwarding/SNAT is intentionally scoped to `10.71.0.0/24` only;
- host-originated Moscow traffic must not be made to masquerade as the client subnet;
- the Moscow default route must remain unchanged.

## Moscow Boundary

This network stage must not modify on Moscow:

```text
ip rule 10710
routing table 1071
main/default route
awg-client
wg-backbone configuration
UFW client forwarding rules
client subnet 10.71.0.0/24
MOEX Bot code or service configuration
```

The only later Moscow/MOEX change is an application-specific proxy setting passed only to the Telegram transport. Global `HTTP_PROXY` or `HTTPS_PROXY` for the whole MOEX runtime is not approved because it could redirect unrelated MOEX, CBR, News, or other HTTP traffic.

## Kazakhstan Boundary

This stage may add only:

- one managed relay executable;
- one managed systemd service;
- one UFW input allow on `wg-backbone` from `10.70.0.1` to `10.70.0.2:18080/tcp`;
- one managed state directory and bounded non-secret evidence.

It must not modify:

```text
Kazakhstan default route
WireGuard peer AllowedIPs
10.71.0.0/24 route
client SNAT
client forwarding
Docker networking
Nginx
Xray
Hysteria2
n8n
Flowise
cloudflared
SSH
IPv4/IPv6 forwarding sysctls
```

## Firewall Contract

The only new firewall behavior is:

```text
ALLOW IN on wg-backbone
source=10.70.0.1
destination=10.70.0.2
protocol=tcp
destination_port=18080
owner_comment=vps-tier-kz-moex-telegram-relay
```

No public-interface listener or public UFW allow is permitted.

## Fail-Closed Behavior

- If `wg-backbone` is down, the relay is unreachable from Moscow.
- If the relay is unavailable, Telegram delivery fails without falling back to Moscow direct egress.
- If the CONNECT target is not exactly `api.telegram.org:443`, the relay rejects it.
- No generic Internet proxy capability is authorized.
- No automatic fallback to another host or target is authorized.

## Secret Boundary

The relay and vps-tier repository must never receive or persist:

- Telegram bot token;
- Telegram chat ID;
- Telegram message body;
- complete Telegram request URL containing a token;
- any MOEX application secret.

The HTTPS tunnel keeps these values inside the end-to-end TLS session.

## Apply Gate

Before any mutation on Kazakhstan, the managed apply script must prove:

```text
HOST_IPV4=194.32.142.88
BACKBONE=active
BACKBONE_IPV4=10.70.0.2
MOSCOW_PEER=reachable
KAZAKHSTAN_DIRECT_TELEGRAM_TCP443=reachable
PORT_18080=unused
UFW=active
PROTECTED_SERVICES=healthy
DEFAULT_ROUTE=snapshotted
CLIENT_SNAT=snapshotted
```

If Kazakhstan itself cannot connect to `api.telegram.org:443`, apply must stop before mutation.

## Runtime Acceptance

After Git merge and Kazakhstan apply:

1. relay service is active and enabled;
2. listener exists only on `10.70.0.2:18080`;
3. UFW allow is present only on `wg-backbone` from `10.70.0.1`;
4. Moscow can perform an HTTPS request to `https://api.telegram.org` using `http://10.70.0.2:18080` as the explicit proxy;
5. direct Moscow Telegram reachability may remain blocked;
6. client VPN egress remains Kazakhstan `194.32.142.88`;
7. rule `10710`, table `1071`, client SNAT, and both host default routes remain unchanged;
8. protected services remain healthy;
9. no secrets are printed or committed.

Only after this network acceptance may MOEX Bot wire the proxy into the Telegram transport and repeat the S6.2B live delivery/dedupe smoke.

## Rollback

Rollback removes only task-owned state:

- UFW relay allow;
- relay systemd unit;
- relay executable;
- relay managed state.

It must not restart or alter the existing VPN, application, Docker, proxy, or database services.
