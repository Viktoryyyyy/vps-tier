#!/usr/bin/env bash
set -euo pipefail

RUNTIME_ENV_FILE="/etc/vps-tier/runtime.env"
BACKUP_ROOT="/var/backups/vps-tier/hysteria2/apply"

HYSTERIA2_CONFIG_TEMPLATE="templates/hysteria2/server.yaml.tpl"
HYSTERIA2_UNIT_TEMPLATE="templates/systemd/hysteria-server.service.tpl"
HYSTERIA2_CONFIG_RENDER=".render/hysteria2/server.yaml"
HYSTERIA2_UNIT_RENDER=".render/systemd/hysteria-server.service"

HYSTERIA2_CONFIG_TARGET="/etc/hysteria/server.yaml"
HYSTERIA2_UNIT_TARGET="/etc/systemd/system/hysteria-server.service"
HYSTERIA2_SERVICE="hysteria-server.service"

UNIT_CHANGED=0

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
    die "scripts/apply_hysteria2.sh must be run as root"
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
  require_file "$HYSTERIA2_CONFIG_TEMPLATE"
  require_file "$HYSTERIA2_UNIT_TEMPLATE"
}

require_runtime_var() {
  var_name="$1"
  eval "var_value=\${$var_name:-}"
  [ -n "$var_value" ] || die "missing required runtime variable: $var_name"
}

require_hysteria2_runtime() {
  require_runtime_var VPS_HYSTERIA2_ENABLED
  [ "$VPS_HYSTERIA2_ENABLED" = "true" ] || die "VPS_HYSTERIA2_ENABLED must be true for Hysteria2 apply"
  require_runtime_var VPS_HYSTERIA2_PORT
  require_runtime_var VPS_HYSTERIA2_AUTH_MODE
  require_runtime_var VPS_HYSTERIA2_AUTH_SECRET
  require_runtime_var VPS_HYSTERIA2_CERT_PATH
  require_runtime_var VPS_HYSTERIA2_KEY_PATH
  require_runtime_var VPS_HYSTERIA2_BIN_PATH
  require_runtime_var VPS_HYSTERIA2_UP_Mbps
  require_runtime_var VPS_HYSTERIA2_DOWN_Mbps
  require_runtime_var VPS_HYSTERIA2_MASQUERADE_URL
  case "$VPS_HYSTERIA2_PORT" in (*[!0-9]*|'') die "VPS_HYSTERIA2_PORT must be numeric" ;; esac
  case "$VPS_HYSTERIA2_UP_Mbps" in (*[!0-9]*|'') die "VPS_HYSTERIA2_UP_Mbps must be numeric" ;; esac
  case "$VPS_HYSTERIA2_DOWN_Mbps" in (*[!0-9]*|'') die "VPS_HYSTERIA2_DOWN_Mbps must be numeric" ;; esac
  [ "${VPS_HYSTERIA2_CERT_PATH#/}" != "$VPS_HYSTERIA2_CERT_PATH" ] || die "VPS_HYSTERIA2_CERT_PATH must be absolute"
  [ "${VPS_HYSTERIA2_KEY_PATH#/}" != "$VPS_HYSTERIA2_KEY_PATH" ] || die "VPS_HYSTERIA2_KEY_PATH must be absolute"
  [ "${VPS_HYSTERIA2_BIN_PATH#/}" != "$VPS_HYSTERIA2_BIN_PATH" ] || die "VPS_HYSTERIA2_BIN_PATH must be absolute"
  case "${VPS_HYSTERIA2_OBFS_ENABLED:-false}" in
    true) require_runtime_var VPS_HYSTERIA2_OBFS_PASSWORD ;;
    false) : ;;
    *) die "VPS_HYSTERIA2_OBFS_ENABLED must be true or false" ;;
  esac
}

render_hysteria2() {
  rm -rf .render/hysteria2 .render/systemd
  mkdir -p .render/hysteria2 .render/systemd
  python3 - "$HYSTERIA2_CONFIG_TEMPLATE" "$HYSTERIA2_CONFIG_RENDER" "$HYSTERIA2_UNIT_TEMPLATE" "$HYSTERIA2_UNIT_RENDER" <<'PY'
import os
import re
import sys

pairs = [(sys.argv[1], sys.argv[2]), (sys.argv[3], sys.argv[4])]
pattern = re.compile(r"\$\{([A-Za-z0-9_]+)\}")

for src, dst in pairs:
    with open(src, "r", encoding="utf-8") as f:
        data = f.read()

    def repl(match):
        key = match.group(1)
        if key not in os.environ:
            return match.group(0)
        return os.environ[key]

    if os.path.basename(src) == "server.yaml.tpl" and os.environ.get("VPS_HYSTERIA2_OBFS_ENABLED", "false") != "true":
        data = re.sub(r"\n# Optional obfuscation\..*?\n# Bandwidth hints", "\n# Bandwidth hints", data, flags=re.S)
    data = pattern.sub(repl, data)
    os.makedirs(os.path.dirname(dst), exist_ok=True)
    with open(dst, "w", encoding="utf-8") as f:
        f.write(data)
PY
}

validate_no_unresolved_placeholders() {
  if grep -R -n -E '\$\{[A-Za-z0-9_]+\}|\{\{[^}]+\}\}|__[A-Za-z0-9_]+__' .render/hysteria2 .render/systemd >/tmp/vps-hysteria2-placeholders.$$; then
    echo "ERROR: unresolved placeholders in rendered Hysteria2 files" >&2
    sed -n "1,50p" /tmp/vps-hysteria2-placeholders.$$ >&2
    rm -f /tmp/vps-hysteria2-placeholders.$$
    exit 1
  fi
  rm -f /tmp/vps-hysteria2-placeholders.$$
}

validate_hysteria2_rendered_files() {
  require_file "$HYSTERIA2_CONFIG_RENDER"
  require_file "$HYSTERIA2_UNIT_RENDER"
  grep -q '^listen: ":' "$HYSTERIA2_CONFIG_RENDER" || die "rendered Hysteria2 config missing listen"
  grep -q '^auth:' "$HYSTERIA2_CONFIG_RENDER" || die "rendered Hysteria2 config missing auth"
  grep -q '^tls:' "$HYSTERIA2_CONFIG_RENDER" || die "rendered Hysteria2 config missing tls"
  grep -q '^ExecStart=.* server -c /etc/hysteria/server.yaml$' "$HYSTERIA2_UNIT_RENDER" || die "rendered Hysteria2 unit has unexpected ExecStart"
  awk '!/^[[:space:]]*#/' "$HYSTERIA2_CONFIG_RENDER" "$HYSTERIA2_UNIT_RENDER" | grep -n -E "${path_x}|${path_n}|systemctl[[:space:]].*(${svc_x}|${svc_n})|service[[:space:]].*(${svc_x}|${svc_n})" >/tmp/vps-hysteria2-scope.$$ || true
  if [ -s /tmp/vps-hysteria2-scope.$$ ]; then
    echo "ERROR: rendered Hysteria2 files contain forbidden non-Hysteria2 scope" >&2
    sed -n "1,50p" /tmp/vps-hysteria2-scope.$$ >&2
    rm -f /tmp/vps-hysteria2-scope.$$
    exit 1
  fi
  rm -f /tmp/vps-hysteria2-scope.$$
}

validate_with_hysteria2_when_possible() {
  [ -x "$VPS_HYSTERIA2_BIN_PATH" ] || { ok "Hysteria2 binary absent; native config validation skipped"; return 0; }
  if "$VPS_HYSTERIA2_BIN_PATH" server --help 2>&1 | grep -qiE 'check|test|validate'; then
    if "$VPS_HYSTERIA2_BIN_PATH" server -c "$HYSTERIA2_CONFIG_RENDER" check >/dev/null 2>&1; then
      ok "Hysteria2 native config validation completed"
      return 0
    fi
    if "$VPS_HYSTERIA2_BIN_PATH" server -c "$HYSTERIA2_CONFIG_RENDER" test >/dev/null 2>&1; then
      ok "Hysteria2 native config validation completed"
      return 0
    fi
    if "$VPS_HYSTERIA2_BIN_PATH" server -c "$HYSTERIA2_CONFIG_RENDER" validate >/dev/null 2>&1; then
      ok "Hysteria2 native config validation completed"
      return 0
    fi
    die "Hysteria2 native config validation was advertised but failed"
  fi
  ok "Hysteria2 native config validation unsupported; skipped"
}

backup_one() {
  live_path="$1"
  backup_path="$BACKUP_DIR/${live_path#/}"
  mkdir -p "$(dirname "$backup_path")"
  if [ -e "$live_path" ]; then
    cp -a "$live_path" "$backup_path"
    printf 'file\t%s\t%s\tpresent\n' "$live_path" "$backup_path" >> "$BACKUP_DIR/MANIFEST.tsv"
  else
    printf 'file\t%s\t%s\tabsent\n' "$live_path" "$backup_path" >> "$BACKUP_DIR/MANIFEST.tsv"
  fi
}

atomic_install() {
  src="$1"
  target="$2"
  mode="$3"
  require_file "$src"
  target_dir="$(dirname "$target")"
  target_base="$(basename "$target")"
  mkdir -p "$target_dir"
  tmp="$(mktemp "$target_dir/.${target_base}.hysteria2.XXXXXX")"
  cp -f "$src" "$tmp"
  chown root:root "$tmp"
  chmod "$mode" "$tmp"
  if [ ! -e "$target" ] || ! cmp -s "$tmp" "$target"; then
    mv -f "$tmp" "$target"
    [ "$target" != "$HYSTERIA2_UNIT_TARGET" ] || UNIT_CHANGED=1
  else
    rm -f "$tmp"
  fi
}

require_root
require_repo_root
require_readable "$RUNTIME_ENV_FILE"
require_cmd python3
require_cmd grep
require_cmd mktemp
require_cmd cmp
require_cmd systemctl

set -a
. "$RUNTIME_ENV_FILE"
set +a

require_hysteria2_runtime
render_hysteria2
ok "Hysteria2 render completed"
validate_no_unresolved_placeholders
validate_hysteria2_rendered_files
validate_with_hysteria2_when_possible

BACKUP_ID="$(date -u +%Y%m%dT%H%M%SZ)"
BACKUP_DIR="$BACKUP_ROOT/$BACKUP_ID"
mkdir -p "$BACKUP_DIR"
chmod 0700 "$BACKUP_DIR"
printf 'created_by\tscripts/apply_hysteria2.sh\ncreated_at_utc\t%s\n' "$BACKUP_ID" > "$BACKUP_DIR/MANIFEST.tsv"
backup_one "$HYSTERIA2_CONFIG_TARGET"
backup_one "$HYSTERIA2_UNIT_TARGET"
ok "backup_set=$BACKUP_DIR"

atomic_install "$HYSTERIA2_CONFIG_RENDER" "$HYSTERIA2_CONFIG_TARGET" 0600
atomic_install "$HYSTERIA2_UNIT_RENDER" "$HYSTERIA2_UNIT_TARGET" 0644
ok "Hysteria2 managed files installed atomically"

if [ "$UNIT_CHANGED" -eq 1 ]; then
  systemctl daemon-reload
  ok "systemctl daemon-reload"
fi

systemctl enable "$HYSTERIA2_SERVICE" >/dev/null
systemctl restart "$HYSTERIA2_SERVICE"
ok "systemctl restart $HYSTERIA2_SERVICE"

HEAD_SHA="$(git -c safe.directory="$PWD" rev-parse --short HEAD 2>/dev/null || true)"
echo "DONE: Hysteria2-only apply completed"
[ -n "$HEAD_SHA" ] && echo "HEAD=$HEAD_SHA"
echo "BACKUP_SET=$BACKUP_DIR"
