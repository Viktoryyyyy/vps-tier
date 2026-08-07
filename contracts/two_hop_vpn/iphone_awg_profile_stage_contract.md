# iPhone AmneziaWG Profile — Stage 7 Contract

## Scope

Stage 7 renders the first iPhone AmneziaWG client profile on the Moscow VPS from the already accepted Stage-5 runtime key material and AWG parameters. The complete profile remains outside Git and must not be printed into logs, chat, PRs, or evidence.

## Profile

```text
client_address=10.71.0.2/32
endpoint=147.45.184.140:443
mtu=1280
dns=1.1.1.1
ipv4_allowed_ips=0.0.0.0/0
ipv6_allowed_ips=::/0
persistent_keepalive=25
```

The profile reuses the server-local `iphone.key` and AWG J/S/H parameters created in Stage 5. No new client identity is generated.

## IPv6 Policy

The initial architecture remains IPv4-only on the server path. The client profile captures `::/0` so unmanaged IPv6 is sent toward the VPN instead of bypassing it. Stage 8 must prove that IPv6 does not escape when the tunnel is active.

## DNS Policy

The client resolver is `1.1.1.1`. Because IPv4 full-tunnel routing sends `0.0.0.0/0` through Moscow and Kazakhstan, DNS traffic to this resolver must follow the Kazakhstan egress path. Stage 8 validates DNS behavior end to end.

## Runtime Output

The managed renderer writes only:

```text
/var/lib/vps-tier/iphone-awg-profile/iphone-awg.conf
/var/lib/vps-tier/iphone-awg-profile/state.env
/var/lib/vps-tier/iphone-awg-profile/evidence.md
```

The directory is mode `0700`; profile and state/evidence files are mode `0600`.

## Secret Boundary

Forbidden in Git, PRs, logs, chat, and observed evidence:

- client private key;
- complete client profile;
- QR payload containing the profile;
- AWG parameter values.

Allowed evidence includes file path, mode, SHA-256, endpoint, client address, DNS choice, full-tunnel flags, parser result, and presence checks.

## Acceptance

```text
PROFILE_RENDERED=yes
PROFILE_MODE=600
STAGE5_CLIENT_IDENTITY=reused
AWG_PARAMETERS=reused
PROFILE_PARSER=passed
IPV4_FULL_TUNNEL=yes
IPV6_FAIL_CLOSED_CAPTURE=yes
SECRETS_PRINTED=no
```

Import and live handshake are not Stage-7 render acceptance; they are validated after the profile is transferred securely to the iPhone.
