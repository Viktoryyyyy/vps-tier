#!/usr/bin/env bash
set -euo pipefail

BACKUP_ROOT="/var/backups/vps-tier/hysteria2/apply"

HYSTERIA2_CONFIG_TARGET="/etc/hysteria/server.yaml"
HYSTERIA2_UNIT_TARGET="/etc/systemd/system/hysteria-server.service"
HYSTERIA2_SERVICE="hysteria-server.service"

UNIT_RESTORED=0

svc_x="xray"
svc_n="nginx"
path_x="/usr/local/etc/xray"
path_n="/etc/nginx"

 die() {
  echo "ERROR: $*" >&2
  exit 1
}

ok() {
  echo "OK: $*"
}

require_root() {
  if [ "${EUID:-$(id -u)}" -ne 0 ]; then
    die "scripts/rollback_hysteria2.sh must be run as root"
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

backup_status_for() {
  target="$1"
  awk -F '\t' -v t="$target" '$1 == "file" && $2 == t {print $4; found=1} END {if (!found) exit 1}' "$BACKUP_DIR/MANIFEST.tsv"
}

validate_restored_scope() {
  for f in "$(backup_path_for "$HYSTERIA2_CONFIG_TARGET")" "$(backup_path_for "$HYSTERIA2_UNIT_TARGET")"; do
    [ -e "$f" ] || continue
    if grep -n -E "${path_x}|${path_n}|systemctl[[:space:]].*(${svc_x}|${svc_n})|service[[:space:]].*(${svc_x}|${svc_n})" "$f" >/tmp/vps-hysteria2-rollback-scope.$$; then
      echo "ERROR: Hysteria2 rollback backup contains forbidden non-Hysteria2 scope" >&2
      sed -n "1,50p" /tmp/vps-hysteria2-rollback-scope.$$ >&2
      rm -f /tmp/vps-hysteria2-rollback-scope.$$
      exit 1
    fi
  done
  rm -f /tmp/vps-hysteria2-rollback-scope.$$
}

validate_with_hysteria2_when_possible() {
  cfg="$(backup_path_for "$HYSTERIA2_CONFIG_TARGET")"
  [ -f "$cfg" ] || { ok "Hysteria2 config was absent in backup; native validation skipped"; return 0; }
  bin_path="$(awk '/^ExecStart=/ {print $1}' "$(backup_path_for "$HYSTERIA2_UNIT_TARGET")" 2>/dev/null | sed 's/^ExecStart=//' || true)"
  [ -n "$bin_path" ] || { ok "Hysteria2 unit absent; native validation skipped"; return 0; }
  [ -x "$bin_path" ] || { ok "Hysteria2 binary absent; native validation skipped"; return 0; }
  if "$bin_path" server --help 2>&1 | grep -qiE 'check|test|validate'; then
    if "$bin_path" server -c "$cfg" check >/dev/null 2>&1; then
      ok "Hysteria2 native backup validation completed"
      return 0
    fi
    if "$bin_path" server -c "$cfg" test >/dev/null 2>&1; then
      ok "Hysteria2 native backup validation completed"
      return 0
    fi
    if "$bin_path" server -c "$cfg" validate >/dev/null 2>&1; then
      ok "Hysteria2 native backup validation completed"
      return 0
    fi
    die "Hysteria2 native backup validation was advertised but failed"
  fi
  ok "Hysteria2 native config validation unsupported; skipped"
}

atomic_restore_or_remove() {
  target="$1"
  status="$(backup_status_for "$target")" || die "backup manifest lacks target: $target"
  backup_file="$(backup_path_for "$target")"
  target_dir="$(dirname "$target")"
  target_base="$(basename "$target")"
  case "$status" in
    present)
      require_file "$backup_file"
      mkdir -p "$target_dir"
      owner="$(stat -c '%u' "$backup_file")"
      group="$(stat -c '%g' "$backup_file")"
      mode="$(stat -c '%a' "$backup_file")"
      tmp="$(mktemp "$target_dir/.${target_base}.hysteria2-rollback.XXXXXX")"
      cp -f "$backup_file" "$tmp"
      chown "$owner:$group" "$tmp"
      chmod "$mode" "$tmp"
      mv -f "$tmp" "$target"
      [ "$target" != "$HYSTERIA2_UNIT_TARGET" ] || UNIT_RESTORED=1
      ;;
    absent)
      rm -f "$target"
      [ "$target" != "$HYSTERIA2_UNIT_TARGET" ] || UNIT_RESTORED=1
      ;;
    *)
      die "invalid backup status for $target: $status"
      ;;
  esac
}

require_root
require_cmd awk
require_cmd grep
require_cmd mktemp
require_cmd systemctl

[ -d "$BACKUP_ROOT" ] || die "no Hysteria2 backup root exists: $BACKUP_ROOT"
BACKUP_DIR="$(ls -1dt "$BACKUP_ROOT"/* 2>/dev/null | head -n 1 || true)"
[ -n "$BACKUP_DIR" ] || die "no Hysteria2 backup set exists under: $BACKUP_ROOT"
[ -d "$BACKUP_DIR" ] || die "latest Hysteria2 backup set is not a directory: $BACKUP_DIR"
require_file "$BACKUP_DIR/MANIFEST.tsv"
grep -qx $'created_by\tscripts/apply_hysteria2.sh' "$BACKUP_DIR/MANIFEST.tsv" || die "latest Hysteria2 backup set was not created by scripts/apply_hysteria2.sh"

backup_status_for "$HYSTERIA2_CONFIG_TARGET" >/dev/null || die "backup manifest missing Hysteria2 config target"
backup_status_for "$HYSTERIA2_UNIT_TARGET" >/dev/null || die "backup manifest missing Hysteria2 unit target"
validate_restored_scope
validate_with_hysteria2_when_possible

atomic_restore_or_remove "$HYSTERIA2_CONFIG_TARGET"
atomic_restore_or_remove "$HYSTERIA2_UNIT_TARGET"
ok "Hysteria2 managed files restored atomically"

if [ "$UNIT_RESTORED" -eq 1 ]; then
  systemctl daemon-reload
  ok "systemctl daemon-reload"
fi

if [ -f "$HYSTERIA2_UNIT_TARGET" ]; then
  systemctl restart "$HYSTERIA2_SERVICE"
  ok "systemctl restart $HYSTERIA2_SERVICE"
else
  systemctl stop "$HYSTERIA2_SERVICE" >/dev/null 2>&1 || true
  ok "Hysteria2 unit absent after rollback; service stopped when present"
fi

echo "DONE: Hysteria2-only rollback completed"
echo "BACKUP_SET=$BACKUP_DIR"
