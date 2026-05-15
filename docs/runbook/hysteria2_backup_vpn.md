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

This document is not a runtime apply record. It contains no credentials, no generated client profiles, and no server-specific runtime.env values.

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

## Canonical Install Policy

```text
INSTALL_SOURCE=official_hysteria_project_only
THIRD_PARTY_INSTALLERS=forbidden
PREFERRED_INSTALL_METHOD=direct_official_release_binary
OFFICIAL_DEPLOYMENT_SCRIPT=allowed_only_if_version_pin_supported_and_binary_path_is_verified
CANONICAL_BINARY_PATH=/usr/local/bin/hysteria
CANONICAL_SERVICE_UNIT=/etc/systemd/system/hysteria-server.service
CANONICAL_CONFIG_PATH=/etc/hysteria/server.yaml
```

The canonical installation source is the official Hysteria project release artifact only. Third-party installers, repackaged binaries, distribution-specific wrapper scripts, panel installers, and convenience scripts from unrelated repositories are forbidden.

The preferred installation method is a direct official Hysteria release binary copied to `/usr/local/bin/hysteria`. The official deployment script may be used only if the operator can pin or record the exact resulting version and can verify that the installed binary path is `/usr/local/bin/hysteria` before any Git-managed apply is attempted.

`VPS_HYSTERIA2_BIN_PATH` in `/etc/vps-tier/runtime.env` must resolve to `/usr/local/bin/hysteria` for the first controlled implementation unless a later Git commit explicitly changes this runbook and the runtime contract together.

Expected binary ownership and mode:

```text
PATH=/usr/local/bin/hysteria
OWNER=root:root
MODE=0755
TYPE=regular_executable_file
```

## Version Policy

```text
VERSION_POLICY=pinned_preferred
LATEST_POLICY=allowed_only_with_recorded_evidence
VERSION_EVIDENCE_REQUIRED=yes
```

Pinned Hysteria2 version is preferred for implementation. If an operator uses an official `latest` release path, the installed version must be recorded in implementation evidence before apply.

Required evidence format must not include secrets:

```text
HYSTERIA2_BINARY_PATH=/usr/local/bin/hysteria
HYSTERIA2_VERSION=<output_of_version_command>
HYSTERIA2_VERSION_POLICY=pinned|latest_recorded
```

Server implementation must stop if the binary exists but the version cannot be read.

## Systemd Conflict Policy

```text
SYSTEMD_CANONICAL_UNIT=hysteria-server.service
GIT_MANAGED_UNIT=/etc/systemd/system/hysteria-server.service
DEFAULT_INSTALLER_UNIT_ALLOWED=no_for_runtime_control
CONFLICT_POLICY=disable_mask_or_remove_default_unit_before_git_apply
```

The Git-managed unit rendered from `templates/systemd/hysteria-server.service.tpl` is canonical for this project.

If an official installer creates a default systemd unit such as `hysteria-server.service`, `hysteria.service`, or another Hysteria service wrapper, that default unit must not remain active unless it is exactly the Git-managed `/etc/systemd/system/hysteria-server.service` produced by this repository.

Before running `scripts/apply_hysteria2.sh`, the operator must verify that no non-canonical Hysteria systemd unit is enabled, active, or bound to `udp/8443`. If a default installer unit exists, it must be stopped and disabled before Git-managed apply. Masking or removing the default unit is allowed only for Hysteria units and must not touch Xray, nginx, SSH, certbot, firewall, or reboot behavior.

`systemctl daemon-reload` is allowed only to register the Git-managed Hysteria unit. It must not be paired with xray, nginx, SSH, certbot, or firewall changes.

## Validation Commands

These are validation requirements for the later server implementation phase. They do not contain secrets and must be executed as observed-only checks before apply or as post-apply evidence after approved Hysteria2-only apply.

Binary existence and metadata:

```bash
command -v hysteria
test -x /usr/local/bin/hysteria
stat -c '%U:%G %a %n' /usr/local/bin/hysteria
/usr/local/bin/hysteria version
```

Native config validation must be attempted if supported by the installed binary. Accepted validation verbs are checked in this order:

```bash
/usr/local/bin/hysteria server -c /etc/hysteria/server.yaml check
/usr/local/bin/hysteria server -c /etc/hysteria/server.yaml test
/usr/local/bin/hysteria server -c /etc/hysteria/server.yaml validate
```

If the installed binary does not support native config validation, this must be recorded as:

```text
HYSTERIA2_NATIVE_CONFIG_VALIDATION=unsupported_by_binary
```

Service and listener checks:

```bash
systemctl --no-pager --full status hysteria-server.service
systemctl is-enabled hysteria-server.service
ss -lunp | grep ':8443'
ss -lntp | grep -E ':(443|80|8443|22)\b'
```

Expected listener proof:

```text
udp/8443=hysteria2_present_when_enabled
udp/8443=absent_after_rollback_or_service_disabled
tcp/443=xray_unchanged
tcp/80=nginx_unchanged
tcp/8443=nginx_unchanged
tcp/22=ssh_unchanged
```

## Install Procedure Boundary

The install phase is separate from Git-managed runtime apply.

Allowed install-only target:

```text
/usr/local/bin/hysteria
```

Forbidden install-phase targets:

```text
/usr/local/etc/xray/config.json
/etc/nginx/sites-enabled/sub
/etc/nginx/sites-enabled/sub.stferry.com
/etc/ssh/sshd_config
/etc/vps-tier/runtime.env
/var/www/sub
client subscription files
firewall rules
```

Operator-safe sequence for later implementation:

```text
1. Verify Git HEAD and this runbook version.
2. Run observed-only checks for current Xray, nginx, SSH, and udp/8443 state.
3. Install only the official Hysteria binary to /usr/local/bin/hysteria.
4. Verify owner, mode, path, and version.
5. Verify no non-canonical Hysteria systemd unit is active or enabled.
6. Stop before runtime apply if any install source, version, binary path, or unit conflict is ambiguous.
7. Only after this gate, run the separately approved Git-managed Hysteria2 apply.
```

All server commands for this phase must follow the Server Command Insertion Canon: one copy-safe `sudo bash -lc 'set -euo pipefail ...'` block per step, no hanging heredocs, explicit guards, minimal output, and no printed secrets.

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

## Rollback / Uninstall Boundary

Rollback is Hysteria2-only.

`scripts/rollback_hysteria2.sh` covers only the Git-managed Hysteria2 runtime targets backed up by `scripts/apply_hysteria2.sh`:

```text
/etc/hysteria/server.yaml
/etc/systemd/system/hysteria-server.service
hysteria-server.service state affected only as needed for rollback
```

It does not uninstall the Hysteria2 binary at `/usr/local/bin/hysteria`, does not remove official installer artifacts outside the Git-managed unit/config targets, and does not modify Xray, nginx, SSH, certbot, firewall, reboot behavior, runtime.env values, or client profiles.

Uninstall of `/usr/local/bin/hysteria` is allowed only after explicit uninstall approval and only when Hysteria2 is disabled, rollback has completed or no Git-managed runtime target exists, and no Hysteria listener remains on udp/8443. Uninstall is outside normal rollback.

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

## Server Implementation Gate

Server implementation may proceed only when all gate fields are explicit in this runbook and confirmed in implementation evidence:

```text
INSTALL_SOURCE=explicit
VERSION_POLICY=explicit
BINARY_PATH=explicit
VALIDATION_COMMANDS=explicit
SYSTEMD_CONFLICT_POLICY=explicit
SERVER_IMPLEMENTATION_GATE=passed_only_if_all_above_confirmed
```

Stop conditions:

```text
INSTALL_SOURCE=ambiguous -> STOP
VERSION_POLICY=ambiguous -> STOP
BINARY_PATH=not_/usr/local/bin/hysteria -> STOP
VERSION_COMMAND_FAILS -> STOP
NON_CANONICAL_HYSTERIA_SYSTEMD_UNIT_ACTIVE -> STOP
NATIVE_CONFIG_VALIDATION_ADVERTISED_BUT_FAILS -> STOP
XRAY_NGINX_SSH_FIREWALL_REBOOT_SCOPE_DETECTED -> STOP
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
- install source is official Hysteria project only.
- version policy is pinned-preferred or latest-recorded.
- expected binary path is /usr/local/bin/hysteria.
- systemd conflict policy keeps the Git-managed unit canonical.
- validation commands are defined without secrets.
- install procedure boundary is Hysteria2-only.
- rollback and uninstall boundaries are explicit.
- no secrets are present.
- apply and rollback boundaries are Hysteria2-only.
```
