# Hysteria2 Backup VPN Runbook

## Scope

This runbook describes the operational boundaries for the Hysteria2 backup VPN path.

```text
ROLE=backup_vpn
PRIMARY_VPN=xray_reality_tcp_443
BACKUP_VPN=hysteria2_udp_8443
SERVER_MUTATION_IN_THIS_DOC=none
SECRETS_IN_THIS_DOC=none
```

This document is not an apply procedure. It contains no server commands, no credentials, and no generated client profiles.

## Operating Principle

```text
- Xray Reality on tcp/443 remains the primary VPN path.
- nginx on tcp/80 and tcp/8443 remains unchanged.
- SSH on tcp/22 remains unchanged.
- Hysteria2 is additive and backup-only.
- Hysteria2 must not be used to replace Xray without a separate approved design.
```

## Intended Use

Use Hysteria2 only when the primary Xray path is unavailable or degraded for a specific client/network.

Do not ask existing working Xray/V2Box users to reimport or replace their current profile during the first Hysteria2 phase.

## Port And Protocol

```text
PRIMARY_XRAY=tcp/443
SUBSCRIPTION_NGINX=tcp/8443
HYSTERIA2_BACKUP=udp/8443
SSH=tcp/22
```

Always write protocol and port together. `tcp/8443` and `udp/8443` are different listeners and different services.

## Client Onboarding Boundary

```text
PRIMARY_PROFILE=existing_xray_subscription
BACKUP_PROFILE=hysteria2_reserve_profile
DEFAULT_USER_ACTION=continue_using_xray
BACKUP_USER_ACTION=use_only_if_primary_path_fails
```

Client instructions must be separate from the existing Xray onboarding flow.

Forbidden in Git documentation:

```text
- real Hysteria2 password
- real obfs password
- private key material
- full client URI
- full credential-bearing subscription URL
```

## Monitoring Interpretation

Expected future health fields:

```text
HYSTERIA2_ENABLED=true|false
HYSTERIA2_SERVICE_STATE=active|inactive|failed|absent
HYSTERIA2_UDP_LISTENER=present|absent
HYSTERIA2_PORT=8443
HYSTERIA2_RECENT_ERRORS=<count>
```

Alert meaning:

```text
HYSTERIA2_DISABLED=no_alert
XRAY_UP_HYSTERIA2_DOWN=backup_degraded
XRAY_DOWN_HYSTERIA2_UP=primary_degraded_backup_available
XRAY_DOWN_HYSTERIA2_DOWN=critical_vpn_availability_incident
```

## Apply Boundary For Later Phase

Later apply may only touch:

```text
/etc/hysteria/server.yaml
/etc/systemd/system/hysteria-server.service
hysteria-server.service
```

Later apply must not touch:

```text
/usr/local/etc/xray/config.json
/etc/nginx/sites-enabled/sub
/etc/nginx/sites-enabled/sub.stferry.com
/etc/ssh/sshd_config
certbot configuration
firewall configuration
```

Later apply must not reload or restart:

```text
xray.service
nginx.service
ssh.service
certbot.timer
```

## Rollback Boundary For Later Phase

Rollback is Hysteria2-only.

Expected post-rollback state:

```text
HYSTERIA2_SERVICE=inactive_or_absent
UDP_8443=absent_or_not_hysteria2
TCP_443=xray_unchanged
TCP_80=nginx_unchanged
TCP_8443=nginx_unchanged
TCP_22=ssh_unchanged
```

## Troubleshooting Semantics

```text
SYMPTOM=Hysteria2 unavailable but Xray works
CLASSIFICATION=backup_degraded
ACTION_BOUNDARY=do_not_change_primary_xray

SYMPTOM=Xray unavailable but Hysteria2 works
CLASSIFICATION=primary_degraded_backup_available
ACTION_BOUNDARY=investigate_xray_without_promoting_hysteria2_by_default

SYMPTOM=both paths unavailable
CLASSIFICATION=critical_vpn_availability_incident
ACTION_BOUNDARY=observed_first_diagnostics_before_apply
```

## Acceptance Criteria

```text
RUNBOOK_ACCEPTANCE=passed_when_all_below_true
```

Required:

```text
- Hysteria2 described as backup-only.
- Xray/nginx/SSH preservation is explicit.
- protocol and port labels are explicit.
- client onboarding does not force migration.
- no commands are present.
- no secrets are present.
- apply and rollback boundaries are Hysteria2-only.
```
