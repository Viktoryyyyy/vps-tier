# Hysteria2 Runtime Environment Contract

## Scope

This contract defines server-only runtime variables for the Hysteria2 backup VPN path.

```text
GITHUB_SCOPE=contract_only
SERVER_MUTATION=not_performed
RUNTIME_APPLY=not_performed
SECRETS_IN_GITHUB=forbidden
```

Hysteria2 is additive. It must not change Xray Reality on tcp/443, nginx on tcp/80 or tcp/8443, SSH on tcp/22, certbot, firewall, or reboot behavior.

## Runtime Source

```text
PRIMARY_RUNTIME_ENV=/etc/vps-tier/runtime.env
SECRET_LOCATION=server_only
GIT_TRACKED=no
```

The runtime env file is not committed. Render logic may read it during authorized render/apply phases only.

## Required Variables

When `VPS_HYSTERIA2_ENABLED=true`, the following variables are required:

```text
VPS_HYSTERIA2_ENABLED=true
VPS_HYSTERIA2_HOST=<public host or domain>
VPS_HYSTERIA2_PORT=8443
VPS_HYSTERIA2_AUTH_MODE=password
VPS_HYSTERIA2_AUTH_SECRET=<server-only secret>
VPS_HYSTERIA2_TLS_MODE=cert_file
VPS_HYSTERIA2_CERT_PATH=<server-only cert path>
VPS_HYSTERIA2_KEY_PATH=<server-only key path>
VPS_HYSTERIA2_BIN_PATH=<absolute hysteria binary path>
VPS_HYSTERIA2_UP_Mbps=<integer>
VPS_HYSTERIA2_DOWN_Mbps=<integer>
VPS_HYSTERIA2_MASQUERADE_URL=<https url>
```

## Optional Variables

```text
VPS_HYSTERIA2_OBFS_ENABLED=false|true
VPS_HYSTERIA2_OBFS_PASSWORD=<server-only secret, required only when obfs enabled>
```

If obfuscation is disabled, render logic must omit the `obfs` block or render a validated disabled form that contains no empty secret.

## Validation Requirements

```text
- enabled must be true or false.
- port must be numeric.
- default approved port is 8443/udp.
- port must not be treated as tcp.
- auth secret must be present when enabled=true.
- cert path and key path must be absolute paths when TLS mode requires files.
- binary path must be absolute.
- up/down bandwidth values must be positive integers.
- masquerade URL must be non-empty and must not point to local Xray/nginx/SSH services.
```

## Forbidden Values In Git

```text
- VPS_HYSTERIA2_AUTH_SECRET value
- VPS_HYSTERIA2_OBFS_PASSWORD value
- private key material
- full client URI
- full credential-bearing subscription URL
- rendered server.yaml containing secrets
```

## Evidence Policy

Allowed evidence:

```text
HYSTERIA2_ENABLED=true|false
HYSTERIA2_PORT=8443
HYSTERIA2_AUTH_SECRET_PRESENT=yes|no
HYSTERIA2_OBFS_ENABLED=true|false
HYSTERIA2_OBFS_PASSWORD_PRESENT=yes|no
HYSTERIA2_CERT_PATH_PRESENT=yes|no
HYSTERIA2_KEY_PATH_PRESENT=yes|no
```

Forbidden evidence:

```text
- raw auth secret
- raw obfs password
- raw private key
- full client config
- full client URI
```

## Failure Semantics

```text
MISSING_REQUIRED_VAR=fail_closed
INVALID_PORT=fail_closed
SECRET_RENDERED_TO_GIT=fail_closed
UNRESOLVED_PLACEHOLDER=fail_closed
XRAY_NGINX_SSH_SCOPE_CHANGE=fail_closed
```
