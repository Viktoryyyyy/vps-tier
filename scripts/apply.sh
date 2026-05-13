#!/usr/bin/env bash
set -euo pipefail

RUNTIME_ENV_FILE="/etc/vps-tier/runtime.env"
BACKUP_ROOT="/var/backups/vps-tier/apply"

XRAY_RENDER=".render/xray/config.json"
NGINX_SUB_RENDER=".render/nginx/sub.conf"
NGINX_DOMAIN_RENDER=".render/nginx/sub.stferry.com.conf"

XRAY_TARGET="/usr/local/etc/xray/config.json"
NGINX_SUB_TARGET="/etc/nginx/sites-enabled/sub"
NGINX_DOMAIN_TARGET="/etc/nginx/sites-enabled/sub.stferry.com"

die() {
  echo "ERROR: $*" >&2
  exit 1
}

ok() {
  echo "OK: $*"
}

require_root() {
  if [ "${EUID:-$(id -u)}" -ne 0 ]; then
    die "scripts/apply.sh must be run as root"
  fi
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "missing command: $1"
}

require_file() {
  [ -f "$1" ] || die "missing file: $1"
}

require_readable() {
  [ -r "$1" ] || die "missing or unreadable file: $1"
}

require_repo_root() {
  require_cmd git
  repo_root="$(git -c safe.directory="$PWD" rev-parse --show-toplevel 2>/dev/null)" || die "not inside a Git repository"
  [ "$repo_root" = "$PWD" ] || die "run from repository root: $repo_root"
  require_file "scripts/render.sh"
  require_file "scripts/validate.sh"
}

backup_one() {
  live_path="$1"
  backup_path="$BACKUP_DIR/${live_path#/}"
  mkdir -p "$(dirname "$backup_path")"
  cp -a "$live_path" "$backup_path"
  printf 'file\t%s\t%s\n' "$live_path" "$backup_path" >> "$BACKUP_DIR/MANIFEST.tsv"
}

atomic_install() {
  src="$1"
  target="$2"
  require_file "$src"
  require_file "$target"

  target_dir="$(dirname "$target")"
  target_base="$(basename "$target")"
  owner="$(stat -c '%u' "$target")"
  group="$(stat -c '%g' "$target")"
  mode="$(stat -c '%a' "$target")"
  tmp="$(mktemp "$target_dir/.${target_base}.apply.XXXXXX")"

  cp -f "$src" "$tmp"
  chown "$owner:$group" "$tmp"
  chmod "$mode" "$tmp"
  mv -f "$tmp" "$target"
}

validate_rendered_xray() {
  python3 -m json.tool "$XRAY_RENDER" >/dev/null
  xray run -test -config "$XRAY_RENDER" >/dev/null 2>&1 || die "xray validation failed for rendered config"
}

validate_rendered_nginx() {
  tmp_conf="$(mktemp /tmp/vps-tier-nginx-rendered.XXXXXX.conf)"
  trap 'rm -f "$tmp_conf"' RETURN
  {
    printf 'events {}\n'
    printf 'http {\n'
    printf '  include %s/%s;\n' "$PWD" "$NGINX_SUB_RENDER"
    printf '  include %s/%s;\n' "$PWD" "$NGINX_DOMAIN_RENDER"
    printf '}\n'
  } > "$tmp_conf"
  nginx -t -c "$tmp_conf" >/dev/null 2>&1 || die "nginx validation failed for rendered configs"
  rm -f "$tmp_conf"
  trap - RETURN
}

validate_live_configs() {
  xray run -test -config "$XRAY_TARGET" >/dev/null 2>&1 || die "xray validation failed for live config"
  nginx -t >/dev/null 2>&1 || die "nginx validation failed for live config"
}

reload_or_restart() {
  service_name="$1"
  if systemctl reload "$service_name" >/dev/null 2>&1; then
    ok "systemctl reload $service_name"
  else
    systemctl restart "$service_name" >/dev/null 2>&1 || die "failed to restart $service_name"
    ok "systemctl restart $service_name"
  fi
}

require_root
require_repo_root
require_readable "$RUNTIME_ENV_FILE"
require_cmd python3
require_cmd xray
require_cmd nginx
require_cmd systemctl

bash scripts/render.sh >/dev/null
ok "render completed"

bash scripts/validate.sh >/dev/null
ok "repo validation completed"

require_file "$XRAY_RENDER"
require_file "$NGINX_SUB_RENDER"
require_file "$NGINX_DOMAIN_RENDER"
require_file "$XRAY_TARGET"
require_file "$NGINX_SUB_TARGET"
require_file "$NGINX_DOMAIN_TARGET"

validate_rendered_xray
ok "rendered xray validation completed"
validate_rendered_nginx
ok "rendered nginx validation completed"

BACKUP_ID="$(date -u +%Y%m%dT%H%M%SZ)"
BACKUP_DIR="$BACKUP_ROOT/$BACKUP_ID"
mkdir -p "$BACKUP_DIR"
chmod 0700 "$BACKUP_DIR"
printf 'created_by\tscripts/apply.sh\ncreated_at_utc\t%s\n' "$BACKUP_ID" > "$BACKUP_DIR/MANIFEST.tsv"
backup_one "$XRAY_TARGET"
backup_one "$NGINX_SUB_TARGET"
backup_one "$NGINX_DOMAIN_TARGET"
ok "backup_set=$BACKUP_DIR"

atomic_install "$XRAY_RENDER" "$XRAY_TARGET"
atomic_install "$NGINX_SUB_RENDER" "$NGINX_SUB_TARGET"
atomic_install "$NGINX_DOMAIN_RENDER" "$NGINX_DOMAIN_TARGET"
ok "managed configs replaced atomically"

validate_live_configs
ok "live config validation completed"

reload_or_restart xray
reload_or_restart nginx

HEAD_SHA="$(git -c safe.directory="$PWD" rev-parse --short HEAD 2>/dev/null || true)"
echo "DONE: controlled apply completed"
[ -n "$HEAD_SHA" ] && echo "HEAD=$HEAD_SHA"
echo "BACKUP_SET=$BACKUP_DIR"
