#!/usr/bin/env bash
set -euo pipefail

if [ "${EUID:-$(id -u)}" -ne 0 ]; then
  echo "ERROR: scripts/apply.sh must be run as root (use sudo)." >&2
  exit 1
fi

RUNTIME_ENV_FILE="/etc/vps-tier/runtime.env"
if [ ! -r "$RUNTIME_ENV_FILE" ]; then
  echo "ERROR: required runtime env file missing or unreadable: $RUNTIME_ENV_FILE" >&2
  exit 1
fi
set -a
. ""
set +a

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

USERS_JSON="${USERS_JSON:-${ROOT_DIR}/opt/tg_bot/sot/users.json}"
XRAY_CONFIG_PATH="${XRAY_CONFIG_PATH:-/usr/local/etc/xray/config.json}"
SUB_DIR="${SUB_DIR:-/var/www/sub/s}"
XRAY_INBOUND_MATCH_PROTOCOL="${XRAY_INBOUND_MATCH_PROTOCOL:-vless}"
BUILD_DIR="${BUILD_DIR:-${ROOT_DIR}/.build/uuid_apply}"
PYTHON_BIN="${PYTHON_BIN:-python3}"

die() { echo "ERROR: $*" >&2; exit 1; }
stage() { echo "==> $*"; }

require_file() { [[ -f "$1" ]] || die "missing file: $1"; }
require_cmd() { command -v "$1" >/dev/null 2>&1 || die "missing command: $1"; }

stage "preflight"
require_file "$USERS_JSON"
require_file "$XRAY_CONFIG_PATH"
require_cmd "$PYTHON_BIN"

mkdir -p "$BUILD_DIR"

CLIENTS_JSON="$BUILD_DIR/clients.json"
SUB_OUT_DIR="$BUILD_DIR/sub"
XRAY_CONFIG_NEW="$BUILD_DIR/config.new.json"

stage "render: xray clients block from users.json"
(
  cd "$ROOT_DIR/src/generator"
  "$PYTHON_BIN" render_xray.py --users "$USERS_JSON" --out "$CLIENTS_JSON"
)

stage "render: subscriptions from users.json"
rm -rf "$SUB_OUT_DIR"
mkdir -p "$SUB_OUT_DIR"
(
  cd "$ROOT_DIR/src/generator"
  "$PYTHON_BIN" render_sub.py --users "$USERS_JSON" --out_dir "$SUB_OUT_DIR"
)

stage "render: build new xray config by patching clients"
export XRAY_CONFIG_PATH CLIENTS_JSON XRAY_CONFIG_NEW XRAY_INBOUND_MATCH_PROTOCOL

"$PYTHON_BIN" -c "import json,os
cfg_path=os.environ.get('XRAY_CONFIG_PATH','/usr/local/etc/xray/config.json')
clients_path=os.environ['CLIENTS_JSON']
out_path=os.environ['XRAY_CONFIG_NEW']
match_proto=os.environ.get('XRAY_INBOUND_MATCH_PROTOCOL','vless').strip().lower()
cfg=json.load(open(cfg_path,'r',encoding='utf-8'))
clients_doc=json.load(open(clients_path,'r',encoding='utf-8'))
clients=clients_doc.get('clients')
if not isinstance(clients,list): raise SystemExit('clients.json missing clients list')
inbounds=cfg.get('inbounds')
if not isinstance(inbounds,list) or not inbounds: raise SystemExit('xray config has no inbounds')
patched=False
for inbound in inbounds:
    if not isinstance(inbound,dict): continue
    proto=str(inbound.get('protocol','')).strip().lower()
    if proto!=match_proto: continue
    settings=inbound.get('settings')
    if not isinstance(settings,dict):
        settings={}
        inbound['settings']=settings
    settings['clients']=clients
    patched=True
    break
if not patched: raise SystemExit('no inbound matched protocol')
json.dump(cfg,open(out_path,'w',encoding='utf-8',newline='\n'),ensure_ascii=False,indent=2); open(out_path,'a',encoding='utf-8').write('\n')
"

stage "validate: JSON syntax"
"$PYTHON_BIN" -m json.tool "$XRAY_CONFIG_NEW" >/dev/null

stage "validate: xray -test (if available)"
if command -v xray >/dev/null 2>&1; then
  if xray run -test -config "$XRAY_CONFIG_NEW" >/dev/null 2>&1; then
    echo "xray -test: OK"
  else
    die "xray -test failed for rendered config"
  fi
else
  echo "SKIP: xray binary not found; JSON validated only"
fi

stage "apply: subscriptions (atomic replace per file)"
mkdir -p "$SUB_DIR"
for f in "$SUB_OUT_DIR"/*.txt; do
  [[ -e "$f" ]] || break
  base="$(basename "$f")"
  tmp="${SUB_DIR}/${base}.tmp"
  cp -f "$f" "$tmp"
  chmod 0644 "$tmp" || true
  mv -f "$tmp" "${SUB_DIR}/${base}"
done

stage "apply: xray config (atomic replace)"
tmp_cfg="${XRAY_CONFIG_PATH}.tmp"
cp -f "$XRAY_CONFIG_NEW" "$tmp_cfg"
chmod 0644 "$tmp_cfg" || true
mv -f "$tmp_cfg" "$XRAY_CONFIG_PATH"

stage "reload: xray"
if systemctl reload xray >/dev/null 2>&1; then
  echo "systemctl reload xray: OK"
else
  systemctl restart xray >/dev/null 2>&1 || die "failed to restart xray"
  echo "systemctl restart xray: OK"
fi

stage "done"
echo "clients rendered: $CLIENTS_JSON"
echo "subs rendered dir: $SUB_OUT_DIR"
echo "xray config applied: $XRAY_CONFIG_PATH"
