# Operational Stability After Recovery — 2026-05-14

## Scope

Read-only operational stability closeout after controlled apply incident recovery.

No runtime apply was performed. No rollback was performed. No managed runtime configuration was written. No services were reloaded or restarted.

## Accepted baseline

- Repository: `Viktoryyyyy/vps-tier`
- Branch: `main`
- Accepted baseline commit: `25cf8400254f8504daca299dac0c485c2d7e3e00`
- Baseline commit purpose: regression guard for VLESS client-level `flow`

## Known recovery context

- First controlled runtime apply caused Xray incident: `client flow is empty`.
- Service was restored by removing client-level `flow` from Xray client entries.
- GitHub Source of Truth was corrected.
- Regression guard was added to reject VLESS client-level `flow`.
- Final reconciliation before this closeout showed rendered/live equivalence and zero client-level `flow` keys.

## Server operational stability check

Operator ran a read-only stability command on the VPS.

Observed result:

```text
HEAD_MATCH=passed
RENDER=passed
VALIDATE=passed
XRAY_CONFIG_MATCH=passed
NGINX_CONFIG_MATCH=passed
XRAY_ACTIVE=active
XRAY_ENABLED=enabled
NGINX_ACTIVE=active
NGINX_ENABLED=enabled
PORT_80_LISTENING=yes
PORT_443_LISTENING=yes
PORT_8443_LISTENING=yes
XRAY_RECENT_ERRORS=0
NGINX_RECENT_ERRORS=0
SERVER_MUTATION=none
RUNTIME_APPLY=not_performed
OPERATIONAL_STABILITY=passed
DONE: operational stability check completed
```

## Manual client smoke test

Manual smoke test was performed with the existing V2Box subscription profile.

Observed result:

```text
OLD_PROFILE_CONNECTS=passed
TRAFFIC_THROUGH_VPN=passed
CLIENT_REIMPORT_NEEDED=no
CLIENT_PLATFORM=iOS/V2Box
RESULT=passed
```

## Final verdict

```text
SERVER_CHECK=passed
CLIENT_SMOKE_TEST=passed
SERVER_MUTATION=none
RUNTIME_APPLY=not_performed
OPERATIONAL_STABILITY=passed
```

The recovery phase is closed as stable at baseline `25cf8400254f8504daca299dac0c485c2d7e3e00`.
