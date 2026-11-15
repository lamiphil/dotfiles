#!/usr/bin/env bash
# Apply Philippe's pi-powerline-footer customizations after npm package updates.
# Portable across macOS and Linux; Node.js is the only patching dependency.
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
AGENT_DIR="${PI_CODING_AGENT_DIR:-$HOME/.pi/agent}"
case "$AGENT_DIR" in
  "~") AGENT_DIR="$HOME" ;;
  "~/"*) AGENT_DIR="$HOME/${AGENT_DIR#\~/}" ;;
esac

if ! command -v node >/dev/null 2>&1; then
  echo "Error: Node.js is required (Pi already depends on it)." >&2
  exit 1
fi

resolve_package() {
  local package="$1"
  local candidate root settings_prefix
  local roots=""

  if command -v npm >/dev/null 2>&1; then
    roots="$(npm root -g 2>/dev/null || true)"
  fi

  settings_prefix="$(node -e '
    const fs = require("node:fs");
    const file = process.argv[1];
    try {
      const command = JSON.parse(fs.readFileSync(file, "utf8")).npmCommand;
      if (Array.isArray(command)) {
        const index = command.indexOf("--prefix");
        if (index >= 0 && command[index + 1]) process.stdout.write(command[index + 1]);
      }
    } catch {}
  ' "$AGENT_DIR/settings.json")"

  if [ -n "$settings_prefix" ]; then
    roots="$roots
$settings_prefix/lib/node_modules
$settings_prefix/node_modules"
  fi
  roots="$roots
$AGENT_DIR/npm/lib/node_modules
$AGENT_DIR/npm/node_modules
$AGENT_DIR/npm-global/lib/node_modules"

  if [ -n "${NODE_PATH:-}" ]; then
    roots="$roots
$(printf '%s' "$NODE_PATH" | tr ':' '\n')"
  fi

  while IFS= read -r root; do
    [ -n "$root" ] || continue
    candidate="$root/$package"
    if [ -f "$candidate/package.json" ]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done <<EOF
$roots
EOF

  return 1
}

PKG="${PI_POWERLINE_FOOTER_DIR:-$(resolve_package pi-powerline-footer || true)}"
VIM_PKG="${VIM_MOTIONS_DIR:-$(resolve_package vim-motions-pi || true)}"

if [ -z "$PKG" ] || [ ! -f "$PKG/package.json" ]; then
  echo "Error: pi-powerline-footer is not installed." >&2
  exit 1
fi
if [ -z "$VIM_PKG" ] || [ ! -f "$VIM_PKG/extensions/vim-motion.ts" ]; then
  echo "Error: vim-motions-pi is not installed." >&2
  exit 1
fi
node "$HERE/patch.mjs" "$PKG" "$VIM_PKG/extensions/vim-motion.ts"

# Keep the theme both with the npm package and in the durable user override path.
cp "$HERE/theme.json" "$PKG/theme.json"
mkdir -p "$AGENT_DIR/extensions/powerline-footer"
cp "$HERE/theme.json" "$AGENT_DIR/extensions/powerline-footer/theme.json"

echo "Applied Powerline customizations to: $PKG"
echo "Patched Vim editor integration at: $VIM_PKG"
echo "Run /reload in Pi (or restart Pi) to load the changes."
