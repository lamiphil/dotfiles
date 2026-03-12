#!/usr/bin/env bash

set -u

if ! command -v tailscale >/dev/null 2>&1; then
  exit 0
fi

status_json="$(tailscale status --json 2>/dev/null || true)"

if [ -z "$status_json" ]; then
  tailscale up >/dev/null 2>&1 || true
  exit 0
fi

backend_state="$(python - "$status_json" <<'PY'
import json
import sys

raw = sys.argv[1]

try:
    data = json.loads(raw)
except Exception:
    print("Unknown")
    raise SystemExit(0)

print(data.get("BackendState", "Unknown"))
PY
)"

if [ "$backend_state" = "Running" ]; then
  tailscale down >/dev/null 2>&1 || true
else
  tailscale up >/dev/null 2>&1 || true
fi
