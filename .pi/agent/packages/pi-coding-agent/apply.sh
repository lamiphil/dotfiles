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
    pkg="$(dirname "$pi_real")"
    if [[ -f "$pkg/package.json" ]]; then
      printf '%s\n' "$pkg"
      return 0
    fi
  fi

  for candidate in \
    /opt/pi-coding-agent \
    /usr/local/lib/pi-coding-agent \
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

echo "Done. Restart pi to pick up."
