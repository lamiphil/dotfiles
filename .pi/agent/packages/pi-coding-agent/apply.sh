#!/usr/bin/env bash
# Apply pi-coding-agent core patches.
# Re-run after `pi update`.

set -euo pipefail

PKG="$(dirname "$(readlink -f /opt/homebrew/bin/pi)")"
[[ -d "$PKG" ]] || { echo "Cannot locate pi-coding-agent" >&2; exit 1; }

echo "→ Package: $PKG"

# ── 1. Session selector: purple named sessions ───────────────────────────────
SELECTOR="$PKG/modes/interactive/components/session-selector.js"
if [[ -f "$SELECTOR" ]]; then
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
