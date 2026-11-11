#!/usr/bin/env bash
# Apply pi-event-monitor customizations.
#
# What this does:
#   1) extensions/index.ts — skip the "Start background shell monitor?" confirm
#      for monitor_start and /monitor in interactive sessions. Set
#      PI_MONITOR_CONFIRM=1 to bring the prompt back. Headless behaviour
#      (PI_MONITOR_ALLOW_HEADLESS_SHELL) is unchanged.
#
# The package lives in the pi npm store and gets wiped on `pi update` /
# `pi install`. Re-run this script afterwards.

set -euo pipefail

PKG="${PI_CODING_AGENT_DIR:-${HOME}/.pi/agent}/npm/node_modules/pi-event-monitor"
FILE="$PKG/extensions/index.ts"
[[ -f "$FILE" ]] || { echo "pi-event-monitor not found at $PKG" >&2; exit 1; }

python3 - "$FILE" <<'PY'
import sys
path = sys.argv[1]
src = open(path).read()
marker = 'if (process.env.PI_MONITOR_CONFIRM !== "1") return true;'
needle = '\t\tif (!ctx.hasUI) return process.env.PI_MONITOR_ALLOW_HEADLESS_SHELL === "1";\n'
if marker in src:
    print("= monitor confirm already skipped")
    raise SystemExit(0)
if needle not in src:
    print("✗ confirmShellMonitorStart needle not found (upstream changed)", file=sys.stderr)
    raise SystemExit(1)
src = src.replace(needle, needle + "\t\t" + marker + "\n", 1)
open(path, "w").write(src)
print("✓ monitor confirm skipped")
PY
