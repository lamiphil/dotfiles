#!/usr/bin/env bash
# Apply pi-coding-agent core patches.
# Re-run after `pi update`.

set -euo pipefail

NPM_ROOT="$(npm root -g 2>/dev/null || true)"

resolve_realpath() {
  python3 -c 'import os,sys; print(os.path.realpath(sys.argv[1]))' "$1"
}

resolve_pi_pkg() {
  local pi_bin pi_real pkg candidate

  pi_bin="$(command -v pi 2>/dev/null || true)"
  if [[ -n "${pi_bin:-}" ]]; then
    pi_real="$(resolve_realpath "$pi_bin")"
    # The CLI is normally <package>/dist/cli.js, not at the package root.
    for pkg in "$(dirname "$pi_real")" "$(dirname "$(dirname "$pi_real")")"; do
      if [[ -f "$pkg/package.json" ]]; then
        printf '%s\n' "$pkg"
        return 0
      fi
    done
  fi

  for candidate in \
    /opt/pi-coding-agent \
    /usr/local/lib/pi-coding-agent \
    "${NPM_ROOT:-}/@earendil-works/pi-coding-agent" \
    "${NPM_ROOT:-}/pi-coding-agent"; do
    if [[ -f "$candidate/package.json" ]]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done

  return 1
}

find_session_selector() {
  local root selector

  for root in "$@"; do
    [[ -n "${root:-}" && -d "$root" ]] || continue

    if [[ -f "$root/modes/interactive/components/session-selector.js" ]]; then
      printf '%s\n' "$root/modes/interactive/components/session-selector.js"
      return 0
    fi

    selector="$(find "$root" -path '*/pi-coding-agent/dist/modes/interactive/components/session-selector.js' -print -quit 2>/dev/null || true)"
    if [[ -n "${selector:-}" ]]; then
      printf '%s\n' "$selector"
      return 0
    fi
  done

  return 1
}

PKG="$(resolve_pi_pkg || true)"
[[ -n "${PKG:-}" && -d "$PKG" ]] || { echo "Cannot locate pi-coding-agent" >&2; exit 1; }

echo "→ Package: $PKG"

# ── 1. Session selector: purple named sessions ───────────────────────────────
SELECTOR="$(find_session_selector "$PKG" "$NPM_ROOT" || true)"
if [[ -n "${SELECTOR:-}" && -f "$SELECTOR" ]]; then
  python3 - "$SELECTOR" <<'PY'
import sys
path = sys.argv[1]
src = open(path).read()

if "[pi-config patch:session-color]" in src:
    print("✓ session-selector.js (already patched)")
    sys.exit(0)

import re
# Match any color value in the hasName branch
m = re.search(r'(else if \(hasName\) \{\s+messageColor = ")([^"]+)(")', src)
if not m:
    print("session-selector.js: needle not found", file=sys.stderr); sys.exit(1)
src = src[:m.start()] + m.group(1) + 'thinkingHigh' + m.group(3) + '; // [pi-config patch:session-color]' + src[m.end():]
open(path, 'w').write(src)
print("✓ session-selector.js (purple session names)")
PY
else
  echo "session-selector.js not found — skipping" >&2
fi

# ── 2. Current session highlight (green + bullet marker) ─────────────────
if [[ -f "$SELECTOR" ]]; then
  python3 - "$SELECTOR" <<'PY2'
import sys
path = sys.argv[1]
src = open(path).read()

if "[pi-config patch:current-session-highlight]" in src:
    print("✓ session-selector.js (current-session already patched)")
    sys.exit(0)

import re

# Change current session color from accent to success
m = re.search(r'(else if \(isCurrent\) \{\s+messageColor = ")([^"]+)(")', src)
if m:
    src = src[:m.start()] + m.group(1) + 'success' + m.group(3) + '; // [pi-config patch:current-session-highlight]' + src[m.end():]

# No bullet marker — just color change

open(path, 'w').write(src)
print("✓ session-selector.js (current session green + bullet)")
PY2
fi

# ── 3. Extension selector/input: remove top & bottom border lines ───────────
for NAME in extension-selector extension-input; do
  FILE="$(find "$PKG" -path "*/pi-coding-agent/dist/modes/interactive/components/$NAME.js" -print -quit 2>/dev/null || true)"
  [[ -z "${FILE:-}" ]] && FILE="$PKG/dist/modes/interactive/components/$NAME.js"
  if [[ ! -f "$FILE" ]]; then
    echo "$NAME.js not found — skipping" >&2
    continue
  fi
  python3 - "$FILE" "$NAME" <<'PYBORDER'
import re, sys
path, name = sys.argv[1], sys.argv[2]
src = open(path).read()

MARKER = "[pi-config patch:no-dialog-borders]"
if MARKER in src:
    print(f"✓ {name}.js (no-dialog-borders already patched)")
    sys.exit(0)

# Drop every `this.addChild(new DynamicBorder());` line in the constructor.
# The surrounding Spacer(1) calls stay, keeping the vertical padding.
new, n = re.subn(
    r'^[ \t]*this\.addChild\(new DynamicBorder\(\)\);\n',
    '',
    src,
    flags=re.M,
)
if n == 0:
    print(f"{name}.js: DynamicBorder call not found (upstream changed?)", file=sys.stderr)
    sys.exit(1)

# Leave a marker so the idempotency check picks it up next run.
new = new.replace(
    'import { DynamicBorder } from "./dynamic-border.js";',
    f'// {MARKER} border lines removed from dialog dressing\nimport {{ DynamicBorder }} from "./dynamic-border.js";',
    1,
)

open(path, 'w').write(new)
print(f"✓ {name}.js (removed {n} DynamicBorder line{'s' if n != 1 else ''})")
PYBORDER
done

# ── 4a. Bump pi-ai hardcoded Claude Code version so background workers
#      (observational-memory observer, etc.) can call Opus 5.5+. The
#      foreground stream already overrides this via Pi Black headers,
#      but any path that falls through to the raw OAuth client needs it.
ANTHROPIC_MSG_JS="$(find "$PKG" -path '*/pi-ai/dist/api/anthropic-messages.js' -print -quit 2>/dev/null || true)"
[[ -z "${ANTHROPIC_MSG_JS:-}" ]] && ANTHROPIC_MSG_JS="$PKG/node_modules/@earendil-works/pi-ai/dist/api/anthropic-messages.js"
if [[ ! -f "$ANTHROPIC_MSG_JS" ]]; then
  echo "anthropic-messages.js not found — skipping claudeCodeVersion bump" >&2
else
  python3 - "$ANTHROPIC_MSG_JS" <<'PYCCVER'
import re, sys
path = sys.argv[1]
src = open(path).read()
TARGET = '2.1.280'
if f'const claudeCodeVersion = "{TARGET}"' in src:
    print(f'✓ anthropic-messages.js (claudeCodeVersion already {TARGET})')
    sys.exit(0)
new, n = re.subn(
    r'const claudeCodeVersion = "[\d.]+";',
    f'const claudeCodeVersion = "{TARGET}";',
    src,
    count=1,
)
if n == 0:
    print('claudeCodeVersion const not found — upstream changed?', file=sys.stderr)
    sys.exit(1)
open(path, 'w').write(new)
print(f'✓ anthropic-messages.js (bumped claudeCodeVersion to {TARGET})')
PYCCVER
fi

# ── 4b. Add Claude Opus 5.5 to the Anthropic model catalog ──────────────
ANTHROPIC_JSON="$(find "$PKG" -path '*/pi-ai/dist/providers/data/anthropic.json' -print -quit 2>/dev/null || true)"
[[ -z "${ANTHROPIC_JSON:-}" ]] && ANTHROPIC_JSON="$PKG/node_modules/@earendil-works/pi-ai/dist/providers/data/anthropic.json"
if [[ ! -f "$ANTHROPIC_JSON" ]]; then
  echo "anthropic.json not found — skipping opus-5-5 patch" >&2
else
  python3 - "$ANTHROPIC_JSON" <<'PYOPUS55'
import json, sys
path = sys.argv[1]
with open(path) as f:
    data = json.load(f)
section = data.get("anthropic-messages")
if section is None:
    print("anthropic.json: anthropic-messages section missing", file=sys.stderr)
    sys.exit(1)
if "claude-opus-5-5" in section:
    print("✓ anthropic.json (opus-5-5 already present)")
    sys.exit(0)
section["claude-opus-5-5"] = {
    "id": "claude-opus-5-5",
    "name": "Claude Opus 5.5",
    "api": "anthropic-messages",
    "provider": "anthropic",
    "baseUrl": "https://api.anthropic.com",
    "reasoning": True,
    "input": ["text", "image"],
    "cost": {"input": 4, "output": 20, "cacheRead": 0.2, "cacheWrite": 5},
    "contextWindow": 1000000,
    "maxTokens": 128000,
    "thinkingLevelMap": {
        "off": None, "minimal": None, "low": "low", "medium": "medium",
        "high": "high", "xhigh": "xhigh", "max": "max",
    },
    "compat": {
        "supportsMidConvoEffort": True,
        "supportsMidConvoSystemMessages": True,
        "supportsMidConvoToolChanges": True,
        "forceAdaptiveThinking": True,
        "supportsTemperature": False,
        "supportsStrictTools": True,
    },
}
with open(path, "w") as f:
    json.dump(data, f, indent=2)
    f.write("\n")
print("✓ anthropic.json (added claude-opus-5-5)")
PYOPUS55
fi

echo "Done. Restart pi to pick up."
