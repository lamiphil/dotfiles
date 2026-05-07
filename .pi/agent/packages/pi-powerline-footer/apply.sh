#!/usr/bin/env bash
# Apply pi-powerline-footer customizations.
#
# What this does:
#   1) theme.json    — drops a OneDark Pro color override
#   2) presets.ts    — moves most segments off the top row (custom 'default' preset)
#   3) index.ts      — patches computeResponsiveLayout() so secondary segments
#                       stay on the bottom row instead of being auto-promoted to the
#                       top row when the terminal is wide.
#
# The pi-powerline-footer plugin lives inside the npm package directory and gets
# wiped on `pi update` / `pi install`. Re-run this script afterwards.

set -euo pipefail

PKG=$(node -e 'console.log(require.resolve("pi-powerline-footer/package.json"))' 2>/dev/null \
  | xargs dirname \
  || true)

if [[ -z "${PKG:-}" || ! -d "$PKG" ]]; then
  # Fallback: probe Homebrew default
  if [[ -d /opt/homebrew/lib/node_modules/pi-powerline-footer ]]; then
    PKG=/opt/homebrew/lib/node_modules/pi-powerline-footer
  elif [[ -d /usr/local/lib/node_modules/pi-powerline-footer ]]; then
    PKG=/usr/local/lib/node_modules/pi-powerline-footer
  else
    echo "Cannot locate pi-powerline-footer. Is it installed?" >&2
    exit 1
  fi
fi

HERE="$(cd "$(dirname "$0")" && pwd)"

echo "→ Package: $PKG"

# ── 1. theme.json ────────────────────────────────────────────────────────────
cp "$HERE/theme.json" "$PKG/theme.json"
echo "✓ theme.json"

# ── 2. presets.ts ────────────────────────────────────────────────────────────
# Replace the `default` preset's segment lists.
python3 - "$PKG/presets.ts" <<'PY'
import re, sys
path = sys.argv[1]
src = open(path).read()

new_default = (
    "  default: {\n"
    "    leftSegments: [\"model\", \"thinking\", \"path\"],\n"
    "    rightSegments: [],\n"
    "    secondarySegments: [\"shell_mode\", \"git\", \"extension_statuses\"],\n"
    "    separator: \"powerline-thin\",\n"
    "    colors: DEFAULT_COLORS,\n"
    "    segmentOptions: {\n"
    "      model: { showThinkingLevel: false },\n"
    "      path: { mode: \"basename\" },\n"
    "      git: { showBranch: true, showStaged: true, showUnstaged: true, showUntracked: true },\n"
    "    },\n"
    "  },\n"
)

# Match the existing `default: { ... },` block (greedy until the next preset key).
pat = re.compile(r"  default: \{\n(?:[^\n]*\n)*?  \},\n", re.M)
m = pat.search(src)
if not m:
    print("Could not locate default preset", file=sys.stderr)
    sys.exit(1)
new = src[:m.start()] + new_default + src[m.end():]
open(path, "w").write(new)
print("✓ presets.ts (default preset segments)")
PY

# ── 3. index.ts: disable auto-promotion in computeResponsiveLayout ──────────
python3 - "$PKG/index.ts" <<'PY'
import re, sys
path = sys.argv[1]
src = open(path).read()

# Idempotency: skip if our marker is already present.
if "[pi-config patch]" in src:
    print("✓ index.ts (already patched)")
    sys.exit(0)

NEEDLE = "  // Get all segments: primary first, then secondary"
i = src.find(NEEDLE)
if i == -1:
    print("Could not find computeResponsiveLayout body to patch", file=sys.stderr)
    sys.exit(1)

# Find `return {` block end (the final return inside the function).
end_marker = "  return {\n    topContent: buildContentFromParts(topSegments, presetDef),\n    secondaryContent: buildContentFromParts(secondarySegments, presetDef),\n  };\n}"
j = src.find(end_marker, i)
if j == -1:
    print("Could not find return block to patch", file=sys.stderr)
    sys.exit(1)

replacement = (
    "  // [pi-config patch] Render primary and secondary rows independently.\n"
    "  // Stock behavior auto-promotes secondary segments to the top bar when wide;\n"
    "  // this patch keeps the user-configured split intact at any width.\n"
    "  const mergedSegments = mergeSegmentsWithCustomItems(presetDef, config.customItems);\n"
    "  const primaryIds = [...mergedSegments.leftSegments, ...mergedSegments.rightSegments];\n"
    "  const secondaryIds = mergedSegments.secondarySegments;\n"
    "  const baseOverhead = 2;\n"
    "  const renderRow = (ids: typeof primaryIds): string[] => {\n"
    "    const out: string[] = [];\n"
    "    let used = baseOverhead;\n"
    "    for (const id of ids) {\n"
    "      const r = renderSegmentWithWidth(id, ctx);\n"
    "      if (!r.visible) continue;\n"
    "      const need = r.width + (out.length > 0 ? sepWidth : 0);\n"
    "      if (used + need <= availableWidth) {\n"
    "        out.push(r.content);\n"
    "        used += need;\n"
    "      }\n"
    "    }\n"
    "    return out;\n"
    "  };\n"
    "  const topSegments = renderRow(primaryIds);\n"
    "  const secondarySegments = renderRow(secondaryIds);\n"
    "  return {\n"
    "    topContent: buildContentFromParts(topSegments, presetDef),\n"
    "    secondaryContent: buildContentFromParts(secondarySegments, presetDef),\n"
    "  };\n"
    "}"
)

new_src = src[:i] + replacement + src[j + len(end_marker):]
open(path, "w").write(new_src)
print("✓ index.ts (computeResponsiveLayout)")
PY

echo "Done. Run /reload in pi (or restart) to pick up the changes."
