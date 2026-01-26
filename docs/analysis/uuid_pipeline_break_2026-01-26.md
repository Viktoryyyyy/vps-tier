# UUID pipeline break — 2026-01-26

## Scope
GitHub repository ONLY. Read-only analysis. No server assumptions. No fixes.

## Paths involved (repo tree)
- opt/tg_bot/sot/users.json
- opt/tg_bot/bot.py
- etc/systemd/system/xray.service
- etc/nginx/sites-enabled/sub
- etc/nginx/sites-enabled/sub.stferry.com
- docs/observed/** (evidence only; not generation)

## 1) Where prod UUIDs are defined in Git
UUIDs exist in the repo as user data in SoT:
- opt/tg_bot/sot/users.json (user entries include sub_url; UUID values are not included in this report).

## 2) Where trial UUIDs SHOULD be defined
Trial UUIDs should be defined the same way as prod UUIDs:
- as a user entry in opt/tg_bot/sot/users.json (with its own sub_url and UUID field).

## 3) Which generator / script / template is responsible for xray config
No generator exists in the repository.

Evidence:
- xray service points to /usr/local/etc/xray/config.json (etc/systemd/system/xray.service)
- nginx serves /var/www/sub (etc/nginx/sites-enabled/sub.stferry.com) and aliases /var/www/sub/sub.txt (etc/nginx/sites-enabled/sub)
- SoT contains per-user sub_url values (opt/tg_bot/sot/users.json)
- No repo code writes or renders /var/www/sub/s/*.txt or /usr/local/etc/xray/config.json

## 4) Where the pipeline diverges (single break)
The repo contains SoT (users.json) and pointers to runtime locations (nginx/systemd), but contains no Git-managed generation/apply step that:
- creates per-user subscription files under /var/www/sub/s/<token>.txt, and
- updates the xray clients list in /usr/local/etc/xray/config.json.

## Clear statement
Trial UUIDs are not applied because the repository has no generator/template/pipeline that turns trial user entries in opt/tg_bot/sot/users.json into the applied runtime artifacts (/var/www/sub/s/<token>.txt and /usr/local/etc/xray/config.json).
