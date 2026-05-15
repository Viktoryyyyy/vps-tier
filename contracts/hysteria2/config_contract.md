# Hysteria2 Configuration Contract

## Scope

This contract defines the desired configuration and validation rules for the Hysteria2 backup VPN service.

```text
SERVICE=hysteria2
ROLE=backup_vpn
PROTOCOL=udp
DEFAULT_PORT=8443
PRIMARY_XRAY_IMPACT=none
NGINX_IMPACT=none
SSH_IMPACT=none
```

The Hysteria2 configuration is additive and isolated. It must not require changes to Xray, nginx, SSH, certbot, firewall, or reboot behavior.

## Managed Artifacts

Git templates:

```text
templates/hysteria2/server.yaml.tpl
templates/systemd/hysteria-server.service.tpl
```

Rendered artifacts:

```text
.render/hysteria2/server.yaml
.render/systemd/hysteria-server.service
```

Later runtime targets, only after explicit apply approval:

```text
/etc/hysteria/server.yaml
/etc/systemd/system/hysteria-server.service
```

## Port Contract

```text
HYSTERIA2_LISTEN_PROTOCOL=udp
HYSTERIA2_DEFAULT_PORT=8443
TCP_443_OWNER=xray
TCP_80_OWNER=nginx
TCP_8443_OWNER=nginx
TCP_22_OWNER=ssh
```

Validation must always report protocol and port together, for example `udp/8443`, not just `8443`.

## Service Contract

```text
SERVICE_NAME=hysteria-server.service
SERVICE_MANAGER=systemd
SERVICE_DEPENDS_ON_XRAY=no
SERVICE_DEPENDS_ON_NGINX=no
SERVICE_DEPENDS_ON_SSH=no
SERVICE_RESTART_POLICY=on-failure
```

The unit must not contain service management actions for:

```text
- xray.service
- nginx.service
- ssh.service
- certbot.timer
- firewall services
- reboot or shutdown targets
```

## Template Contract

The Hysteria2 server template may contain placeholders only. It must not contain real secrets.

Allowed placeholder classes:

```text
${VPS_HYSTERIA2_PORT}
${VPS_HYSTERIA2_AUTH_MODE}
${VPS_HYSTERIA2_AUTH_SECRET}
${VPS_HYSTERIA2_CERT_PATH}
${VPS_HYSTERIA2_KEY_PATH}
${VPS_HYSTERIA2_OBFS_PASSWORD}
${VPS_HYSTERIA2_UP_Mbps}
${VPS_HYSTERIA2_DOWN_Mbps}
${VPS_HYSTERIA2_MASQUERADE_URL}
${VPS_HYSTERIA2_BIN_PATH}
```

Forbidden template content:

```text
- real auth secrets
- real obfs passwords
- private key material
- full client URIs
- full subscription URLs containing credentials
- direct references to modifying Xray/nginx/SSH runtime files
```

## Render Contract

Render must fail closed when:

```text
- Hysteria2 is enabled and required variables are missing.
- rendered YAML is invalid.
- rendered systemd unit is structurally invalid.
- rendered artifacts contain unresolved placeholders.
- rendered artifacts would be committed to Git with secrets.
```

Render must not write to:

```text
/etc/hysteria/server.yaml
/etc/systemd/system/hysteria-server.service
/usr/local/etc/xray/config.json
/etc/nginx/sites-enabled/sub
/etc/nginx/sites-enabled/sub.stferry.com
/etc/ssh/sshd_config
```

## Apply Contract For Later Phase

Apply scope must be limited to:

```text
/etc/hysteria/server.yaml
/etc/systemd/system/hysteria-server.service
hysteria-server.service
```

Apply must not:

```text
- reload xray
- restart xray
- reload nginx
- restart nginx
- restart SSH
- change certbot
- change firewall
- reboot the server
```

## Rollback Contract For Later Phase

Rollback scope must be limited to Hysteria2 artifacts and service state.

Expected rollback evidence:

```text
HYSTERIA2_SERVICE=inactive_or_absent
UDP_8443=absent_or_not_hysteria2
TCP_443=xray_unchanged
TCP_80=nginx_unchanged
TCP_8443=nginx_unchanged
TCP_22=ssh_unchanged
```

## Monitoring Contract

Healthcheck additions:

```text
HYSTERIA2_ENABLED=true|false
HYSTERIA2_SERVICE_STATE=active|inactive|failed|absent
HYSTERIA2_UDP_LISTENER=present|absent
HYSTERIA2_PORT=8443
HYSTERIA2_RECENT_ERRORS=<count>
```

Alert classification:

```text
HYSTERIA2_DISABLED=no_alert
XRAY_UP_HYSTERIA2_DOWN=backup_degraded
XRAY_DOWN_HYSTERIA2_UP=primary_degraded_backup_available
XRAY_DOWN_HYSTERIA2_DOWN=critical_vpn_availability_incident
```

## Acceptance Criteria

```text
CONFIG_CONTRACT_ACCEPTANCE=passed_when_all_below_true
```

Required:

```text
- Hysteria2 remains backup-only.
- default listen target is udp/8443.
- service model is systemd-native.
- runtime secrets are server-only.
- Git contains templates/contracts only.
- validation blocks unresolved placeholders.
- validation blocks committed secrets.
- validation blocks unrelated Xray/nginx/SSH scope changes.
- apply and rollback are Hysteria2-only.
```
