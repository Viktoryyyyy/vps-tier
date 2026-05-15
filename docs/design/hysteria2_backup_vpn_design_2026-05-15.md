# Hysteria2 Backup VPN — Design First

## 1. Verdict

```text
HYSTERIA2_BACKUP_VPN_DESIGN=accepted
RUNTIME_APPLY=not_performed
SERVER_MUTATION=not_performed
PRIMARY_XRAY_TCP_443=preserve_unchanged
NGINX_TCP_80_8443=preserve_unchanged
SSH_TCP_22=preserve_unchanged
RECOMMENDED_HYSTERIA2_PORT=udp/8443
GITHUB_SOT_MODEL=required
RUNTIME_SECRET_MODEL=server_only
```

Hysteria2 is designed as an additive reserve VPN path. It does not replace Xray Reality and does not require changes to the existing working Xray, nginx, SSH, certbot, or reboot baseline.

## 2. Design Goals

```text
GOAL_1=add reserve VPN path
GOAL_2=avoid disturbing working Xray Reality on tcp/443
GOAL_3=avoid disturbing nginx on tcp/80 and tcp/8443
GOAL_4=avoid disturbing SSH on tcp/22
GOAL_5=keep Hysteria2 independently renderable, validatable, applicable, and rollbackable
GOAL_6=keep all Hysteria2 secrets server-only
GOAL_7=make monitoring detect backup degradation without treating it as primary outage
```

Primary rule: Hysteria2 is backup-only unless explicitly promoted later by a separate approved design.

## 3. Port Selection Options

### Option A: udp/443

```text
PROS:
- highest chance of passing networks that allow QUIC-like UDP 443
- conventional for modern UDP VPN traffic

CONS:
- shares numeric port with primary Xray Reality tcp/443
- higher operator confusion risk
- future firewall or provider-rule mistakes could affect the primary path
- monitoring must distinguish tcp/443 and udp/443 precisely
```

Assessment: technically valid, but not the lowest-risk first backup port.

### Option B: udp/8443

```text
PROS:
- no protocol collision with nginx tcp/8443
- preserves Xray tcp/443 unchanged
- keeps backup path clearly separate from primary VPN
- easy to monitor as tcp/8443=nginx and udp/8443=hysteria2

CONS:
- some restrictive networks may block non-443 UDP
- numeric overlap with nginx subscription port requires clear protocol labeling
```

Assessment: best first-phase balance of low runtime risk and usable client reachability.

### Option C: udp/10443

```text
PROS:
- very low collision risk
- clear separation from existing production ports

CONS:
- weaker reachability on restrictive networks
- less intuitive for client setup
```

Assessment: reserve candidate if udp/8443 conflicts with provider policy or proves unusable.

### Option D: udp/2083 or udp/2096

```text
PROS:
- alternative TLS-like numeric ports
- lower collision risk than 443

CONS:
- less intuitive
- no clear advantage over udp/8443 for this VPS
```

Assessment: not preferred for this phase.

## 4. Recommended Port Decision

```text
PRIMARY_HYSTERIA2_CANDIDATE=udp/8443
SECONDARY_HYSTERIA2_CANDIDATE=udp/10443
DEFERRED_CANDIDATE=udp/443
```

Use udp/8443 for the first Hysteria2 backup VPN design.

Rationale:

```text
- tcp/443 remains Xray Reality only.
- tcp/80 remains nginx only.
- tcp/8443 remains nginx subscription only.
- tcp/22 remains SSH only.
- udp/8443 creates an additive Hysteria2 path without changing existing TCP listeners.
```

udp/443 is intentionally deferred because this phase prioritizes non-disturbance over maximum UDP reachability.

## 5. Systemd Service Model

```text
SERVICE_NAME=hysteria-server.service
SERVICE_TYPE=systemd-native
SERVICE_SCOPE=independent_backup_vpn_service
DEPENDENCY_ON_XRAY=none
DEPENDENCY_ON_NGINX=none
DEPENDENCY_ON_SSH=none
RESTART_POLICY=on-failure
CONFIG_PATH=/etc/hysteria/server.yaml
```

Service model:

```text
- independent unit
- no embedding into xray.service
- no nginx reload dependency
- no xray reload dependency
- no SSH interaction
- UDP listener only
- failure must not affect Xray/nginx/SSH
```

Systemd semantics:

```text
- order after network-online.target
- restart on failure only
- no ExecStartPre mutation of Xray, nginx, SSH, certbot, or firewall
- no automatic runtime enablement in design phase
```

## 6. Runtime Secret Model

```text
SECRET_STORAGE=server_only
PRIMARY_RUNTIME_ENV=/etc/vps-tier/runtime.env
SECRET_IN_GITHUB=forbidden
SECRET_IN_CHAT=forbidden
SECRET_IN_LOGS=forbidden
```

Hysteria2-specific runtime variables are additive:

```text
VPS_HYSTERIA2_ENABLED
VPS_HYSTERIA2_HOST
VPS_HYSTERIA2_PORT
VPS_HYSTERIA2_AUTH_MODE
VPS_HYSTERIA2_AUTH_SECRET
VPS_HYSTERIA2_TLS_MODE
VPS_HYSTERIA2_CERT_PATH
VPS_HYSTERIA2_KEY_PATH
VPS_HYSTERIA2_OBFS_ENABLED
VPS_HYSTERIA2_OBFS_PASSWORD
VPS_HYSTERIA2_UP_Mbps
VPS_HYSTERIA2_DOWN_Mbps
```

Evidence policy:

```text
ALLOWED:
- enabled/disabled flag
- selected port
- listener presence
- service state
- secret presence yes/no

FORBIDDEN:
- auth secret value
- obfs password value
- private key material
- full client URI
- full credential-bearing subscription URL
```

## 7. GitHub Template Model

Git-tracked desired-state artifacts:

```text
templates/hysteria2/server.yaml.tpl
templates/systemd/hysteria-server.service.tpl
contracts/hysteria2/runtime_env_contract.md
contracts/hysteria2/config_contract.md
docs/runbook/hysteria2_backup_vpn.md
```

Rendered local build artifacts:

```text
.render/hysteria2/server.yaml
.render/systemd/hysteria-server.service
```

Later runtime targets, only after explicit apply approval:

```text
/etc/hysteria/server.yaml
/etc/systemd/system/hysteria-server.service
```

Rules:

```text
- Git contains templates and contracts only.
- Runtime secrets come only from server-side runtime.env or server-only secret files.
- Render must fail closed if enabled=true and required Hysteria2 variables are missing.
- Rendered secret-bearing artifacts must not be committed.
- Existing Xray/nginx templates must not be changed by this Hysteria2-only design.
```

## 8. Validation Model

Static validation:

```text
- YAML syntax is valid.
- systemd unit structure is valid.
- no unresolved placeholders remain.
- no secret-like values are committed.
- no Xray/nginx/SSH managed target is changed by Hysteria2-only scope.
```

Render validation:

```text
- render produces .render/hysteria2/server.yaml when enabled.
- render produces .render/systemd/hysteria-server.service when enabled.
- render fails closed when required Hysteria2 runtime variables are absent.
- render does not write runtime paths.
```

Port validation:

```text
- Hysteria2 uses UDP only.
- selected default is udp/8443.
- tcp/443, tcp/80, tcp/8443, and tcp/22 remain outside Hysteria2 scope.
- validation output must label protocol and port together.
```

Secret validation:

```text
- Git must not contain auth secrets.
- Git must not contain obfs passwords.
- Git must not contain private keys.
- Git must not contain full client URIs.
- Git must not contain full credential-bearing subscription URLs.
```

Service validation:

```text
- unit references only Hysteria2 config path.
- unit has no dependency on xray.service or nginx.service.
- unit has no service-management action for SSH.
- unit has bounded restart behavior.
```

## 9. Apply / Rollback Impact

Apply impact for later approved phase:

```text
XRAY_CONFIG_IMPACT=none
NGINX_CONFIG_IMPACT=none
SSH_CONFIG_IMPACT=none
CERTBOT_IMPACT=none
FIREWALL_IMPACT=none_in_design_phase
NEW_RUNTIME_CONFIG_LATER=/etc/hysteria/server.yaml
NEW_SYSTEMD_UNIT_LATER=/etc/systemd/system/hysteria-server.service
NEW_LISTENER_LATER=udp/8443
```

Rollback impact for later approved phase:

```text
ROLLBACK_SCOPE=hysteria2_only
XRAY_ROLLBACK_ACTION=none
NGINX_ROLLBACK_ACTION=none
SSH_ROLLBACK_ACTION=none
CERTBOT_ROLLBACK_ACTION=none
EXPECTED_POST_ROLLBACK=udp/8443_absent_or_hysteria2_inactive
```

Rollback acceptance:

```text
- tcp/443 still belongs to Xray.
- tcp/80 still belongs to nginx.
- tcp/8443 still belongs to nginx.
- tcp/22 still belongs to SSH.
- Hysteria2 service inactive or absent after rollback.
```

## 10. Client Onboarding Impact

```text
PRIMARY_PROFILE=existing_xray_reality_subscription
BACKUP_PROFILE=hysteria2_reserve_profile
DEFAULT_USER_ACTION=keep_using_xray
BACKUP_USER_ACTION=use_only_if_primary_path_fails
```

Rules:

```text
- existing V2Box/Xray users are not forced to reimport.
- existing subscription endpoint remains unchanged.
- Hysteria2 instructions are separate from Xray instructions.
- first phase must not replace current sub.txt contents.
- any future subscription integration must be additive and clearly labeled backup.
```

Documentation requirements:

```text
- purpose of backup profile
- when to use backup
- protocol/port notation: udp/8443
- supported client list
- no credentials in Git
- troubleshooting for UDP-blocked networks
```

## 11. Monitoring / Healthcheck Impact

Add Hysteria2 status as backup-path signal:

```text
HYSTERIA2_ENABLED=true|false
HYSTERIA2_SERVICE_STATE=active|inactive|failed|absent
HYSTERIA2_UDP_LISTENER=present|absent
HYSTERIA2_PORT=8443
HYSTERIA2_RECENT_ERRORS=count
```

Alert semantics:

```text
- Hysteria2 disabled intentionally: no alert.
- Hysteria2 enabled and failed while Xray is up: backup_degraded.
- Xray up and Hysteria2 down: not primary outage.
- Xray down and Hysteria2 down: critical VPN availability incident.
```

Health log extension:

```text
xray=up|down
nginx=up|down
hysteria2=enabled:up|enabled:down|disabled|absent
udp_8443=listen|absent
```

No secret-bearing health logs are allowed.

## 12. Risks And Mitigations

```text
RISK=UDP blocked by client network
MITIGATION=keep Xray primary; document Hysteria2 as backup only; retain udp/10443 as reserve candidate

RISK=operator confusion between tcp/8443 nginx and udp/8443 Hysteria2
MITIGATION=always write protocol and port together; validation must distinguish tcp and udp

RISK=accidental primary VPN disruption
MITIGATION=Hysteria2-only managed targets; no Xray/nginx reload in Hysteria2 apply scope

RISK=secret leakage to Git
MITIGATION=server-only runtime secret model; secret scanning validation; no committed rendered secret artifacts

RISK=systemd restart loop
MITIGATION=bounded restart policy; monitoring classifies backup failure separately from primary outage

RISK=client confusion
MITIGATION=separate backup onboarding; no forced migration; no default replacement

RISK=false acceptance without evidence
MITIGATION=accept only Git artifacts and, when runtime is later touched, observed evidence from explicit HEAD verification
```

## 13. Phased Implementation Plan

### Phase 1: Git design artifact

```text
SCOPE:
- record this design in Git
- no server access
- no runtime apply
- no package install
- no credentials
```

### Phase 2: Git templates and contracts

```text
SCOPE:
- add Hysteria2 config template
- add Hysteria2 systemd unit template
- add runtime env contract
- add config contract
- add validation requirements

EXCLUDED:
- server mutation
- generated secrets
- service activation
```

### Phase 3: Git validation wiring

```text
SCOPE:
- extend render model for Hysteria2 artifacts
- extend validate model for YAML, systemd, secret, and port checks
- guard against unrelated Xray/nginx/SSH changes

EXCLUDED:
- runtime writes
- service reloads
- firewall changes
```

### Phase 4: Observed-only readiness check

```text
SCOPE:
- clean temporary clone under /tmp
- explicit HEAD verification
- read-only service and listener evidence
- confirm Hysteria2 absent before apply

EXCLUDED:
- package install
- service change
- firewall change
```

### Phase 5: Controlled Hysteria2-only apply

```text
SCOPE:
- apply only approved Hysteria2 files
- verify udp/8443 listener
- verify tcp/443, tcp/80, tcp/8443, and tcp/22 unchanged
- capture bounded observed evidence

EXCLUDED:
- Xray reload
- nginx reload
- SSH restart
- firewall mutation unless separately approved
```

### Phase 6: Backup client documentation

```text
SCOPE:
- add backup-only user instructions
- preserve primary Xray onboarding
- keep credentials out of Git
- avoid automatic subscription replacement
```

## 14. Acceptance Criteria

```text
DESIGN_ACCEPTANCE=passed_when_all_below_true
```

Required criteria:

```text
- Xray Reality tcp/443 preserved unchanged.
- nginx tcp/80 preserved unchanged.
- nginx tcp/8443 preserved unchanged.
- SSH tcp/22 preserved unchanged.
- Hysteria2 defined as additive backup VPN only.
- recommended Hysteria2 port is udp/8443.
- udp/443 is explicitly deferred.
- systemd-native model is defined.
- runtime secret model is server-only.
- GitHub template model is defined.
- validation model covers render, syntax, secret, port, and unrelated-diff guards.
- apply impact is Hysteria2-only.
- rollback impact is Hysteria2-only.
- client onboarding keeps existing Xray users unchanged.
- monitoring adds Hysteria2 as backup/degraded signal.
- no commands are included.
- no secrets are included.
- no runtime apply is included.
```

Final design status:

```text
READY_FOR_GITHUB_DESIGN_ACCEPTANCE=yes
READY_FOR_SERVER_APPLY=no
```
