# Two-Hop VPN Stage 8 Live Acceptance — 2026-08-08

## Scope

This file records non-secret operator observations made after importing the client profiles.

It complements the earlier server-side acceptance evidence for the backbone, Kazakhstan egress, Moscow AWG termination, fail-closed routing, and rendered client profile.

No private key, complete client profile, QR payload, AWG J/S/H parameter value, token, or credential is recorded here.

## Architecture Under Test

```text
client
 -> AmneziaWG UDP/443
 -> Moscow 147.45.184.140
 -> wg-backbone
 -> Kazakhstan 194.32.142.88
 -> Internet
```

Client subnet:

```text
10.71.0.0/24
```

## iPhone End-To-End Acceptance

Dedicated client address:

```text
10.71.0.2/32
```

Rendered profile SHA-256:

```text
bd69cc20bb39e44cabc052e0bea2b5dd209c8142744f2d48da8745b4f895ba7c
```

### Public IPv4

With AmneziaWG enabled on the iPhone, the observed public IPv4 was:

```text
194.32.142.88
```

Result:

```text
CLIENT_CONNECTS_TO_MOSCOW=yes
CLIENT_PUBLIC_EGRESS_KAZAKHSTAN=yes
```

### IPv6 fail-closed

With the tunnel enabled, an IPv6-only address check at `ipv6.icanhazip.com` was not reachable.

Result:

```text
PUBLIC_IPV6_ESCAPE_OBSERVED=no
IPV6_FAIL_CLOSED=passed
```

### Controlled backbone-loss test

Before interruption, an automatic restore timer was scheduled on Moscow for the backbone service.

The Moscow service `wg-quick@wg-backbone.service` was then stopped while the iPhone AmneziaWG tunnel remained enabled.

Observed client result:

```text
Internet access disappeared
```

No fallback Internet path through Moscow was observed.

The automatic restore subsequently returned:

```text
wg-quick@wg-backbone.service=active
```

After restoration, the iPhone Internet connection returned without changing the client profile.

Result:

```text
BACKBONE_LOSS_CLIENT_INTERNET=blocked
MOSCOW_FALLBACK=not_observed
BACKBONE_AUTORESTORE=passed
CLIENT_RECOVERY_AFTER_BACKBONE_RESTORE=passed
```

This is the critical end-to-end proof that the server-side policy rule, dedicated routing table, prohibit default, and Moscow forwarding firewall do not silently use Moscow public egress when Kazakhstan is unavailable.

## Windows Client Observation

Dedicated client address:

```text
10.71.0.3/32
```

Rendered profile SHA-256:

```text
b1ba3e7262ab090836d61f4416ed3599aa30b24e4e036e2d78c85d646a4909c7
```

The Windows AmneziaWG tunnel was observed active while troubleshooting local file transfer to the SberBox.

A Windows `Test-NetConnection` to the SberBox LAN address showed:

```text
SourceAddress=10.71.0.3
TcpTestSucceeded=False
```

After disabling the Windows AmneziaWG tunnel, the browser successfully reached the X-plore Wi-Fi file manager on the local SberBox LAN address.

Interpretation:

```text
WINDOWS_TUNNEL_ACTIVE=observed
WINDOWS_CLIENT_ADDRESS=10.71.0.3
CURRENT_PROFILE_FULL_TUNNEL=yes
LOCAL_LAN_CAPTURE_WHILE_TUNNEL_ON=observed
```

The exact Windows public IPv4 and IPv6 behavior were not separately captured in this acceptance file. Repeat those checks before declaring strict per-device acceptance.

## Sber TV / SberBox Client Observation

Dedicated client address:

```text
10.71.0.4/32
```

Rendered profile SHA-256:

```text
5bffddfc7c27e653c7660bbc09759f37946a7d31a0279338b66f585ae2c14eef
```

The dedicated `sber-tv.conf` profile was transferred to the TV and imported into AmneziaWG.

Observed user result after import and tunnel activation:

```text
YouTube works
```

Result:

```text
SBER_TV_PROFILE_IMPORTED=yes
SBER_TV_INTERNET_FUNCTIONAL=observed
```

The exact TV public IPv4 and IPv6 behavior were not separately captured in this acceptance file. Repeat those checks before declaring strict per-device acceptance.

## Client Independence

The server was provisioned with separate peer identities and `/32` addresses for iPhone, Windows and Sber TV.

```text
iPhone  = 10.71.0.2/32
Windows = 10.71.0.3/32
Sber TV = 10.71.0.4/32
```

A single profile must not be reused across multiple simultaneously active devices.

## Overall Stage-8 Verdict

For the architecture-level acceptance:

```text
IPHONE_PUBLIC_EGRESS_KZ=passed
IPHONE_IPV6_FAIL_CLOSED=passed
BACKBONE_LOSS_FAIL_CLOSED=passed
BACKBONE_RECOVERY=passed
MOSCOW_FALLBACK=blocked_by_observation
WINDOWS_TUNNEL=operational_observation
SBER_TV_TUNNEL=operational_observation
```

Strict per-device public-IP and IPv6 acceptance remains recommended for Windows and Sber TV, but the critical two-hop architecture and fail-closed behavior were proven from the iPhone client.
