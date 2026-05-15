#!/usr/bin/env bash
set -euo pipefail

repo_root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$repo_root"

out_dir=".render"
rm -rf "$out_dir"
mkdir -p "$out_dir"

[ -r /etc/vps-tier/runtime.env ] || { echo "ERROR: missing /etc/vps-tier/runtime.env" >&2; exit 1; }
set -a
. /etc/vps-tier/runtime.env
set +a

found=0

render_one() {
  src="$1"
  dst="$2"
  [ -f "$src" ] || { echo "ERROR: missing template: $src" >&2; exit 1; }
  mkdir -p "$(dirname "$dst")"
  python3 scripts/render_template.py "$src" "$dst"
  found=1
}

render_hysteria2_one() {
  src="$1"
  dst="$2"
  [ -f "$src" ] || { echo "ERROR: missing template: $src" >&2; exit 1; }
  mkdir -p "$(dirname "$dst")"
  python3 - "$src" "$dst" <<'PY'
import os
import re
import sys

src = sys.argv[1]
dst = sys.argv[2]

with open(src, "r", encoding="utf-8") as f:
    data = f.read()

if os.path.basename(src) == "server.yaml.tpl" and os.environ.get("VPS_HYSTERIA2_OBFS_ENABLED", "false") != "true":
    data = re.sub(
        r"\n# Optional obfuscation\..*?\n# Bandwidth hints",
        "\n# Bandwidth hints",
        data,
        flags=re.S,
    )

def repl(match):
    key = match.group(1)
    return os.environ.get(key, match.group(0))

data = re.sub(r"\$\{([A-Z0-9_]+)\}", repl, data)

os.makedirs(os.path.dirname(dst), exist_ok=True)
with open(dst, "w", encoding="utf-8") as f:
    f.write(data)
PY
  found=1
}

for src in runtime/templates/xray/*.template runtime/templates/xray/config.json.template; do
  [ -e "$src" ] || continue
  name="$(basename "$src")"
  name="${name%.template}"
  render_one "$src" "$out_dir/xray/$name"
done

for src in runtime/templates/nginx/*.template runtime/templates/nginx/sub.conf.template; do
  [ -e "$src" ] || continue
  name="$(basename "$src")"
  name="${name%.template}"
  render_one "$src" "$out_dir/nginx/$name"
done

if [ -f templates/hysteria2/server.yaml.tpl ]; then
  render_hysteria2_one templates/hysteria2/server.yaml.tpl "$out_dir/hysteria2/server.yaml"
fi

if [ -f templates/systemd/hysteria-server.service.tpl ]; then
  render_hysteria2_one templates/systemd/hysteria-server.service.tpl "$out_dir/systemd/hysteria-server.service"
fi

[ "$found" -eq 1 ] || { echo "ERROR: no templates found under runtime/templates or Hysteria2 templates" >&2; exit 1; }

if [ -d "$out_dir/hysteria2" ] || [ -d "$out_dir/systemd" ]; then
  if grep -R -n -E '\$\{[A-Z0-9_]+\}|\{\{[^}]+\}\}|__[A-Z0-9_]+__' "$out_dir/hysteria2" "$out_dir/systemd" >/tmp/vps-render-hysteria2-placeholders.$$ 2>/dev/null; then
    echo "ERROR: unresolved placeholders in rendered Hysteria2 files" >&2
    sed -n "1,50p" /tmp/vps-render-hysteria2-placeholders.$$ >&2
    rm -f /tmp/vps-render-hysteria2-placeholders.$$
    exit 1
  fi
  rm -f /tmp/vps-render-hysteria2-placeholders.$$
fi

echo "DONE: rendered repo-local files under $out_dir"
