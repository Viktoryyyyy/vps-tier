# Hysteria2 Server Implementation Evidence — 2026-05-15

## Scope

```text
PROJECT=Personal VPS Resilience Upgrade
PHASE=Hysteria2 Backup VPN — Server Implementation Rerun
EVIDENCE_TYPE=non_secret_observed_closeout
SERVER_MUTATION=controlled_hysteria2_only
RUNTIME_APPLY=hysteria2_only
SECRETS_IN_THIS_DOC=none
```

## GitHub Source Of Truth

```text
FINAL_HEAD=1c4e817899e5923b5f2a1cdbd736ffabd1d59f53
BASELINE_HEAD=c90a6e64d84b14b2cfa0dc5fb18da53f01ed8870
```

Git-only fixes applied during rerun:

```text
20323a7f96f61693999677fdc5c71e8869918b87 fix: add Hysteria2 render validate gate
3bc0e3e833ce287367fb178c9ebdd82814ea8ff3 fix: keep legacy placeholder handling out of Hysteria2 gate
2476618e9e76045548f605d5cc3d4202df22f726 fix: ignore comments in Hysteria2 scope validation
ae6ace3d3faf23a0a44a774a1bd303ce21afc918 fix: validate mixed-case Hysteria2 placeholders
1c4e817899e5923b5f2a1cdbd736ffabd1d59f53 fix: adjust native validation gate
```

## Implementation Result

```text
HYSTERIA2_SERVER_IMPLEMENTATION=passed
HEAD_MATCH=passed
HYSTERIA2_INSTALL=installed
HYSTERIA2_VERSION=v2.9.1
RUNTIME_ENV_HYSTERIA2_VARS=present
RENDER=passed
VALIDATE=passed
HYSTERIA2_ONLY_APPLY=passed
HYSTERIA2_ACTIVE=active
HYSTERIA2_ENABLED=enabled
HYSTERIA2_UDP_LISTENING=yes
XRAY_STILL_WORKS=yes
NGINX_STILL_WORKS=yes
SSH_STILL_WORKS=yes
OLD_XRAY_CLIENT_SMOKE=passed
HYSTERIA2_CLIENT_SMOKE=passed_server_local_official_client
SERVER_MUTATION=controlled_hysteria2_only
RUNTIME_APPLY=hysteria2_only
BLOCKERS=none
```

## Non-secret Observed Evidence

```text
HYSTERIA2_BINARY_PATH=/usr/local/bin/hysteria
HYSTERIA2_VERSION=v2.9.1
HYSTERIA2_SERVICE=hysteria-server.service
HYSTERIA2_SERVICE_STATE=active
HYSTERIA2_SERVICE_ENABLED=enabled
HYSTERIA2_UDP_LISTENER=*:8443
HYSTERIA2_LISTENER_PROCESS=hysteria
HYSTERIA2_CONFIG_TARGET=/etc/hysteria/server.yaml
HYSTERIA2_UNIT_TARGET=/etc/systemd/system/hysteria-server.service
HYSTERIA2_BACKUP_SET=/var/backups/vps-tier/hysteria2/apply/20260515T101847Z
```

Primary services after apply:

```text
xray.service=active_enabled
nginx.service=active_enabled
ssh.service=active_enabled
tcp/22=still_listening
tcp/80=still_listening
tcp/443=still_listening
tcp/8443=still_listening
```

Regression evidence:

```text
NON_HYSTERIA2_HASH_CHECK=passed
XRAY_RENDER_LIVE_MATCH=passed
NGINX_RENDER_LIVE_MATCH=passed
RECENT_XRAY_ERRORS=none_after_apply
RECENT_NGINX_ERRORS=none_after_apply
```

Smoke tests:

```text
OLD_XRAY_CLIENT_SMOKE=passed
HYSTERIA2_LOCAL_CLIENT_SMOKE=passed
HYSTERIA2_TRAFFIC_WORKS=yes
```

## Secret Handling

No Hysteria2 auth secret, subscription URL, private key, certificate private key, full client URI, or user credential was recorded in this evidence file.

## Final Verdict

```text
VERDICT=passed
FOLLOWUP_REQUIRED=none_for_server_implementation
```
