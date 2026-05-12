#!/usr/bin/env bash
set -euo pipefail

repo_root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$repo_root"

out_dir=".render"
rm -rf "$out_dir"
mkdir -p "$out_dir"

found=0

render_one() {
  src="$1"
  dst="$2"
  [ -f "$src" ] || { echo "ERROR: missing template: $src" >&2; exit 1; }
  mkdir -p "$(dirname "$dst")"
  cp "$src" "$dst"
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

[ "$found" -eq 1 ] || { echo "ERROR: no templates found under runtime/templates" >&2; exit 1; }

if grep -R -n -E "\\{\\{[^}]+\\}\\}|__[A-Z0-9_]+__" "$out_dir" >/tmp/vps-render-placeholders.$$; then
  echo "ERROR: unresolved placeholders in rendered files" >&2
  sed -n "1,50p" /tmp/vps-render-placeholders.$$ >&2
  rm -f /tmp/vps-render-placeholders.$$
  exit 1
fi
rm -f /tmp/vps-render-placeholders.$$

echo "DONE: rendered repo-local files under $out_dir"
