#!/usr/bin/env bash
# Apply @juicesharp/rpiv-ask-user-question customizations.
#
# What this does:
#   1) ask-user-question.ts — route the questionnaire through Pi's inline
#      select/input dialog primitives instead of the full-screen tabbed
#      overlay. Upstream reserves the RPC fallback path (runRpcQuestionnaire)
#      for `ctx.mode === "rpc"` clients. In TUI mode Pi renders those same
#      primitives in the editor area (showExtensionSelector /
#      showExtensionInput) rather than as a top-anchored overlay, so the
#      assistant transcript stays fully visible above the question box.
#
# The @juicesharp/rpiv-ask-user-question package lives inside the pi npm
# store and gets wiped on `pi update` / `pi install`. Re-run this script
# afterwards.

set -euo pipefail

NPM_ROOT="$(npm root -g 2>/dev/null || true)"
PI_NPM_ROOT="${PI_CODING_AGENT_DIR:-${HOME}/.pi/agent}/npm/node_modules"
SETTINGS_FILE="${HOME}/.pi/agent/settings.json"

settings_npm_prefix() {
  [[ -f "$SETTINGS_FILE" ]] || return 1
  python3 - "$SETTINGS_FILE" <<'PY'
import json, sys
path = sys.argv[1]
try:
    data = json.load(open(path))
except Exception:
    raise SystemExit(1)
cmd = data.get("npmCommand") or []
for i, token in enumerate(cmd):
    if token == "--prefix" and i + 1 < len(cmd):
        print(cmd[i + 1])
        raise SystemExit(0)
raise SystemExit(1)
PY
}

resolve_pkg() {
  local pkg="$1"
  local resolved=""
  local prefix=""

  prefix="$(settings_npm_prefix 2>/dev/null || true)"
  if [[ -n "${prefix:-}" && -d "$prefix/lib/node_modules/${pkg}" ]]; then
    printf '%s\n' "$prefix/lib/node_modules/${pkg}"
    return 0
  fi

  resolved="$(NODE_PATH="$NPM_ROOT" node -e "try { console.log(require.resolve('${pkg}/package.json')); } catch (e) {}" 2>/dev/null || true)"
  if [[ -n "${resolved:-}" ]]; then
    dirname "$resolved"
    return 0
  fi

  for candidate in \
    "${PI_NPM_ROOT}/${pkg}" \
    "/opt/homebrew/lib/node_modules/${pkg}" \
    "/usr/local/lib/node_modules/${pkg}" \
    "${NPM_ROOT:-}/${pkg}"; do
    if [[ -d "$candidate" ]]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done

  return 1
}

PKG="$(resolve_pkg @juicesharp/rpiv-ask-user-question || true)"

if [[ -z "${PKG:-}" || ! -d "$PKG" ]]; then
  echo "Cannot locate @juicesharp/rpiv-ask-user-question. Is it installed?" >&2
  exit 1
fi

echo "→ Package: $PKG"

# ── 1. Force the inline dialog path (skip the tabbed overlay) ───────────────
python3 - "$PKG/ask-user-question.ts" <<'PYINLINE'
import sys
path = sys.argv[1]
src = open(path).read()

MARKER = "[pi-config patch:inline-dialog]"
if MARKER in src:
    print("✓ ask-user-question.ts (inline-dialog already patched)")
    sys.exit(0)

NEEDLE = '\t\t\tif ((ctx as { mode?: string }).mode === "rpc" && hasDialogUI(ctx.ui)) {'
REPL = (
    f'\t\t\t// {MARKER} always use Pi\'s inline editor-area dialogs; the tabbed\n'
    f'\t\t\t// overlay covers the assistant transcript above it.\n'
    '\t\t\tif (hasDialogUI(ctx.ui)) {'
)

if NEEDLE not in src:
    print("ask-user-question.ts: mode-gate needle not found (upstream changed?)", file=sys.stderr)
    sys.exit(1)

open(path, 'w').write(src.replace(NEEDLE, REPL, 1))
print("✓ ask-user-question.ts (inline dialog path forced)")
PYINLINE

echo "Done. Restart pi (Ctrl+D then pi) to pick up the changes."
