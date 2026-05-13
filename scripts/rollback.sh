#!/usr/bin/env bash
set -euo pipefail

BACKUP_ROOT="/var/backups/vps-tier/apply"

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
    die "scripts/rollback.sh must be run as root"
  fi
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "missing command: $1"
}

require_file() {
  [ -f "$1" ] || die "missing file: $1"
}

backup_path_for() {
  target="$1"
  printf '%s/%s\n' "$BACKUP_DIR" "${target#/}"
}

atomic_restore() {
  backup_file="$1"
  target="$2"
  require_file "$backup_file"

  target_dir="$(dirname "$target")"
  [ -d "$target_dir" ] || die "missing target directory: $target_dir"
  target_base="$(basename "$target")"
  owner="$(stat -c '%u' "$backup_file")"
  group="$(stat -c '%g' "$backup_file")"
  mode="$(stat -c '%a' "$backup_file")"
  tmp="$(mktemp "$target_dir/.${target_base}.rollback.XXXXXX")"

  cp -f "$backup_file" "$tmp"
  chown "$owner:$group" "$tmp"
  chmod "$mode" "$tmp"
  mv -f "$tmp" "$target"
}

validate_backup_xray() {
  backup_xray="$(backup_path_for "$XRAY_TARGET")"
  xray run -test -config "$backup_xray" >/dev/null 2>&1 || die "xray validation failed for backup config"
}

validate_backup_nginx_when_possible() {
  backup_sub="$(backup_path_for "$NGINX_SUB_TARGET")"
  backup_domain="$(backup_path_for "$NGINX_DOMAIN_TARGET")"
  tmp_conf="$(mktemp /tmp/vps-tier-nginx-rollback.XXXXXX.conf)"
  trap 'rm -f "$tmp_conf"' RETURN
  {
    printf 'events {}\n'
    printf 'http {\n'
    printf '  include %s;\n' "$backup_sub"
    printf '  include %s;\n' "$backup_domain"
    printf '}\n'
  } > "$tmp_conf"
  nginx -t -c "$tmp_conf" >/dev/null 2>&1 || die "nginx validation failed for backup configs"
  rm -f "$tmp_conf"
  trap - RETURN
}

validate_live_configs() {
  xray run -test -config "$XRAY_TARGET" >/dev/null 2>&1 || die "xray validation failed for restored live config"
  nginx -t >/dev/null 2>&1 || die "nginx validation failed for restored live config"
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
require_cmd xray
require_cmd nginx
require_cmd systemctl
require_cmd mktemp

[ -d "$BACKUP_ROOT" ] || die "no backup root exists: $BACKUP_ROOT"
BACKUP_DIR="$(ls -1dt "$BACKUP_ROOT"/* 2>/dev/null | head -n 1 || true)"
[ -n "$BACKUP_DIR" ] || die "no backup set exists under: $BACKUP_ROOT"
[ -d "$BACKUP_DIR" ] || die "latest backup set is not a directory: $BACKUP_DIR"
require_file "$BACKUP_DIR/MANIFEST.tsv"
grep -qx $'created_by\tscripts/apply.sh' "$BACKUP_DIR/MANIFEST.tsv" || die "latest backup set was not created by scripts/apply.sh"

require_file "$(backup_path_for "$XRAY_TARGET")"
require_file "$(backup_path_for "$NGINX_SUB_TARGET")"
require_file "$(backup_path_for "$NGINX_DOMAIN_TARGET")"

validate_backup_xray
ok "backup xray validation completed"
validate_backup_nginx_when_possible
ok "backup nginx validation completed"

atomic_restore "$(backup_path_for "$XRAY_TARGET")" "$XRAY_TARGET"
atomic_restore "$(backup_path_for "$NGINX_SUB_TARGET")" "$NGINX_SUB_TARGET"
atomic_restore "$(backup_path_for "$NGINX_DOMAIN_TARGET")" "$NGINX_DOMAIN_TARGET"
ok "managed configs restored atomically"

validate_live_configs
ok "restored live config validation completed"

reload_or_restart xray
reload_or_restart nginx

echo "DONE: controlled rollback completed"
echo "BACKUP_SET=$BACKUP_DIR"
