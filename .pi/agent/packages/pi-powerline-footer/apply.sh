#!/usr/bin/env bash
# Apply pi-powerline-footer customizations.
#
# What this does:
#   1) theme.json    — drops a OneDark Pro color override
#   2) presets.ts    — moves most segments off the top row (custom 'default' preset)
#   3) index.ts      — patches computeResponsiveLayout() so secondary segments
#                       stay on the bottom row instead of being auto-promoted to the
#                       top row when the terminal is wide.
#                    — also patches /vibe generate to accept multi-word themes.
#
# The pi-powerline-footer plugin lives inside the npm package directory and gets
# wiped on `pi update` / `pi install`. Re-run this script afterwards.

set -euo pipefail

NPM_ROOT="$(npm root -g 2>/dev/null || true)"
PKG=$(NODE_PATH="$NPM_ROOT" node -e 'console.log(require.resolve("pi-powerline-footer/package.json"))' 2>/dev/null \
  | xargs -r dirname \
  || true)

if [[ -z "${PKG:-}" || ! -d "$PKG" ]]; then
  # Fallback: probe common global npm locations (macOS Homebrew, Linux/NVM).
  for candidate in \
    /opt/homebrew/lib/node_modules/pi-powerline-footer \
    /usr/local/lib/node_modules/pi-powerline-footer \
    "${NPM_ROOT:-}/pi-powerline-footer"; do
    if [[ -d "$candidate" ]]; then
      PKG="$candidate"
      break
    fi
  done
fi

if [[ -z "${PKG:-}" || ! -d "$PKG" ]]; then
  echo "Cannot locate pi-powerline-footer. Is it installed?" >&2
  exit 1
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
    "    secondarySegments: [\"shell_mode\", \"git\"],\n"
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

# ── 4. index.ts: support multi-word themes in `/vibe generate` ────────────
python3 - "$PKG/index.ts" <<'PY'
import sys
path = sys.argv[1]
src = open(path).read()

if "[pi-config patch:vibe-multiword]" in src:
    print("✓ index.ts (vibe multi-word already patched)")
    sys.exit(0)

NEEDLE = (
    "      // /vibe generate <theme> [count] - generate vibes and save to file\n"
    "      if (subcommand === \"generate\") {\n"
    "        const theme = parts[1];\n"
    "        const parsedCount = Number.parseInt(parts[2] ?? \"\", 10);\n"
    "        const count = Number.isFinite(parsedCount)\n"
    "          ? Math.min(Math.max(Math.floor(parsedCount), 1), 500)\n"
    "          : 100;\n"
)

REPL = (
    "      // /vibe generate <theme> [count] - generate vibes and save to file\n"
    "      // [pi-config patch:vibe-multiword] last numeric arg is the count;\n"
    "      // everything else (joined by spaces) is the theme.\n"
    "      if (subcommand === \"generate\") {\n"
    "        const _gArgs = parts.slice(1);\n"
    "        let _gCount = 100;\n"
    "        let _gThemeParts = _gArgs;\n"
    "        if (_gArgs.length > 0) {\n"
    "          const _last = _gArgs[_gArgs.length - 1] ?? \"\";\n"
    "          if (/^\\d+$/.test(_last)) {\n"
    "            _gCount = Math.min(Math.max(Math.floor(Number.parseInt(_last, 10)), 1), 500);\n"
    "            _gThemeParts = _gArgs.slice(0, -1);\n"
    "          }\n"
    "        }\n"
    "        const theme = _gThemeParts.join(\" \").trim();\n"
    "        const count = _gCount;\n"
)

if NEEDLE not in src:
    print("Could not find /vibe generate body to patch (upstream changed?)", file=sys.stderr)
    sys.exit(1)

open(path, "w").write(src.replace(NEEDLE, REPL, 1))
print("✓ index.ts (vibe multi-word)")
PY

# ── 5. shell-session.ts: enable alias expansion in managed bash ──────────
python3 - "$PKG/bash-mode/shell-session.ts" <<'PY'
import sys
path = sys.argv[1]
src = open(path).read()

if "[pi-config patch:bash-aliases]" in src:
    print("✓ shell-session.ts (bash-aliases already patched)")
    sys.exit(0)

NEEDLE = (
    "  if (shellName.includes(\"bash\")) {\n"
    "    return `\n"
    "__pi_eval() {\n"
)

REPL = (
    "  if (shellName.includes(\"bash\")) {\n"
    "    // [pi-config patch:bash-aliases] enable alias expansion so user aliases\n"
    "    // (ll, k, lg, etc.) work in powerline bash-mode commands.\n"
    "    return `\n"
    "shopt -s expand_aliases\n"
    "[ -f ~/.bash_aliases ] && source ~/.bash_aliases\n"
    "__pi_eval() {\n"
)

if NEEDLE not in src:
    print("Could not find bash init block (upstream changed?)", file=sys.stderr)
    sys.exit(1)

open(path, "w").write(src.replace(NEEDLE, REPL, 1))
print("✓ shell-session.ts (bash-aliases)")
PY

# ── 5. Rounded editor: suppress editor borders + embed rounded corners in powerline rows

# 5a. Suppress the editor's own horizontal borders (replace with empty lines)
# Search both vendor namespaces (pi was forked from @mariozechner to @earendil-works)
EDITOR_JS="$(find \
  /opt/homebrew/lib/node_modules/@earendil-works \
  /opt/homebrew/lib/node_modules/@mariozechner \
  /usr/local/lib/node_modules/@earendil-works \
  /usr/local/lib/node_modules/@mariozechner \
  "${NPM_ROOT:-}/@earendil-works" \
  "${NPM_ROOT:-}/@mariozechner" \
  -path '*/pi-tui/dist/components/editor.js' -print -quit 2>/dev/null || true)"
if [[ -n "$EDITOR_JS" && -f "$EDITOR_JS" ]]; then
  python3 - "$EDITOR_JS" <<'PYEDITOR'
import sys
path = sys.argv[1]
src = open(path).read()

if "[pi-config patch:suppress-editor-border]" in src:
    print("✓ editor.js (borders already suppressed)")
    sys.exit(0)

# Replace top border (non-scroll case) with empty line
NT = '''        else {
            result.push(horizontal.repeat(width));
        }
        // Render each visible layout line'''
RT = '''        else {
            // [pi-config patch:suppress-editor-border]
            result.push(" ".repeat(width));
        }
        // Render each visible layout line'''

# Replace bottom border (non-scroll case) with empty line
NB = '''        else {
            result.push(horizontal.repeat(width));
        }
        // Add autocomplete list if active'''
RB = '''        else {
            result.push(" ".repeat(width));
        }
        // Add autocomplete list if active'''

if NT not in src:
    print("Could not find top border needle", file=sys.stderr); sys.exit(1)
if NB not in src:
    print("Could not find bottom border needle", file=sys.stderr); sys.exit(1)

src = src.replace(NT, RT, 1).replace(NB, RB, 1)
open(path, 'w').write(src)
print("✓ editor.js (borders suppressed)")
PYEDITOR
else
  echo "Could not find pi-tui editor.js — skipping border suppression" >&2
fi

# 5b. Wrap powerline top/secondary lines with rounded corners
python3 - "$PKG/index.ts" <<'PYPOWERLINE'
import sys
path = sys.argv[1]
src = open(path).read()

if "[pi-config patch:rounded-powerline]" in src:
    print("✓ index.ts (rounded-powerline already patched)")
    sys.exit(0)

# Patch renderPowerlineTopLines to wrap content in ╭───╮
NT = '''  function renderPowerlineTopLines(width: number, theme: Theme): string[] {
    if (!currentCtx) return [];

    const layout = getResponsiveLayout(width, theme);
    return layout.topContent ? [layout.topContent] : [];
  }'''

RT = '''  // [pi-config patch:rounded-powerline]
  function renderPowerlineTopLines(width: number, theme: Theme): string[] {
    if (!currentCtx) return [];
    const layout = getResponsiveLayout(width, theme);
    if (!layout.topContent) return [];
    const border = (s: string) => theme.fg("borderMuted", s);
    const inner = layout.topContent;
    const innerW = visibleWidth(inner);
    const fill = Math.max(0, width - innerW - 2);
    return [border("╭") + inner + border("─".repeat(fill) + "╮")];
  }'''

# Patch renderPowerlineSecondaryLines similarly
NS = '''  function renderPowerlineSecondaryLines(width: number, theme: Theme): string[] {
    if (!currentCtx) return [];

    const layout = getResponsiveLayout(width, theme);
    return layout.secondaryContent ? [layout.secondaryContent] : [];
  }'''

RS = '''  function renderPowerlineSecondaryLines(width: number, theme: Theme): string[] {
    if (!currentCtx) return [];
    const layout = getResponsiveLayout(width, theme);
    if (!layout.secondaryContent) return [];
    const border = (s: string) => theme.fg("borderMuted", s);
    const inner = layout.secondaryContent;
    const innerW = visibleWidth(inner);
    const fill = Math.max(0, width - innerW - 2);
    return [border("╰") + inner + border("─".repeat(fill) + "╯")];
  }'''

if NT not in src:
    print("Could not find renderPowerlineTopLines", file=sys.stderr); sys.exit(1)
if NS not in src:
    print("Could not find renderPowerlineSecondaryLines", file=sys.stderr); sys.exit(1)

src = src.replace(NT, RT, 1).replace(NS, RS, 1)
open(path, 'w').write(src)
print("✓ index.ts (rounded-powerline)")
PYPOWERLINE

# ── 6. powerline-config.ts + index.ts: support "secondary-right" position ────
python3 - "$PKG/powerline-config.ts" <<'PYCFG'
import sys
path = sys.argv[1]
src = open(path).read()

if "[pi-config patch:secondary-right]" in src:
    print("✓ powerline-config.ts (secondary-right already patched)")
    sys.exit(0)

NN = '''function normalizeCustomItemPosition(value: unknown): CustomItemPosition {
  if (value === "left" || value === "right" || value === "secondary") return value;
  return "right";
}'''
RN = '''function normalizeCustomItemPosition(value: unknown): CustomItemPosition {
  // [pi-config patch:secondary-right]
  if (value === "left" || value === "right" || value === "secondary" || value === "secondary-right") return value as CustomItemPosition;
  return "right";
}'''

NM = '''  for (const item of customItems) {
    const segmentId: StatusLineSegmentId = `custom:${item.id}`;
    if (item.position === "left") left.push(segmentId);
    else if (item.position === "secondary") secondary.push(segmentId);
    else right.push(segmentId);
  }

  return { leftSegments: left, rightSegments: right, secondarySegments: secondary };'''
RM = '''  const secondaryRight: StatusLineSegmentId[] = [];
  for (const item of customItems) {
    const segmentId: StatusLineSegmentId = `custom:${item.id}`;
    if (item.position === "left") left.push(segmentId);
    else if (item.position === "secondary") secondary.push(segmentId);
    else if ((item.position as string) === "secondary-right") secondaryRight.push(segmentId);
    else right.push(segmentId);
  }

  return { leftSegments: left, rightSegments: right, secondarySegments: secondary, secondaryRightSegments: secondaryRight } as any;'''

for needle, repl in [(NN, RN), (NM, RM)]:
    if needle not in src:
        print("powerline-config.ts: needle not found", file=sys.stderr); sys.exit(1)
    src = src.replace(needle, repl, 1)

open(path, "w").write(src)
print("✓ powerline-config.ts (secondary-right)")
PYCFG

python3 - "$PKG/index.ts" <<'PYIDX'
import sys
path = sys.argv[1]
src = open(path).read()

if "[pi-config patch:secondary-right-render]" in src:
    print("✓ index.ts (secondary-right-render already patched)")
    sys.exit(0)

# Replace the patched renderPowerlineSecondaryLines from the rounded patch with
# one that supports a right-aligned tail group.
NEEDLE = '''  function renderPowerlineSecondaryLines(width: number, theme: Theme): string[] {
    if (!currentCtx) return [];
    const layout = getResponsiveLayout(width, theme);
    if (!layout.secondaryContent) return [];
    const border = (s: string) => theme.fg("borderMuted", s);
    const inner = layout.secondaryContent;
    const innerW = visibleWidth(inner);
    const fill = Math.max(0, width - innerW - 2);
    return [border("╰") + inner + border("─".repeat(fill) + "╯")];
  }'''

REPL = '''  // [pi-config patch:secondary-right-render]
  function renderPowerlineSecondaryLines(width: number, theme: Theme): string[] {
    if (!currentCtx) return [];
    const layout = getResponsiveLayout(width, theme) as any;
    const border = (s: string) => theme.fg("borderMuted", s);
    const left = layout.secondaryContent || "";
    const right = layout.secondaryRightContent || "";
    if (!left && !right) return [];
    const leftW = visibleWidth(left);
    const rightW = visibleWidth(right);
    const fill = Math.max(0, width - leftW - rightW - 2);
    return [border("╰") + left + border("─".repeat(fill)) + right + border("╯")];
  }'''

if NEEDLE not in src:
    print("index.ts: secondary render needle not found (was rounded patch applied?)", file=sys.stderr); sys.exit(1)
src = src.replace(NEEDLE, REPL, 1)

# Also extend computeResponsiveLayout to render secondaryRightContent.
# Find the function and add a new variable computation near the existing secondarySegments.
LAYOUT_NEEDLE = '''  const topSegments = renderRow(primaryIds);
  const secondarySegments = renderRow(secondaryIds);
  return {
    topContent: buildContentFromParts(topSegments, presetDef),
    secondaryContent: buildContentFromParts(secondarySegments, presetDef),
  };
}'''

LAYOUT_REPL = '''  const topSegments = renderRow(primaryIds);
  const secondarySegments = renderRow(secondaryIds);
  const secondaryRightIds = (mergedSegments as any).secondaryRightSegments || [];
  const secondaryRightSegments = renderRow(secondaryRightIds);
  return {
    topContent: buildContentFromParts(topSegments, presetDef),
    secondaryContent: buildContentFromParts(secondarySegments, presetDef),
    secondaryRightContent: buildContentFromParts(secondaryRightSegments, presetDef),
  } as any;
}'''

if LAYOUT_NEEDLE not in src:
    print("index.ts: layout return needle not found", file=sys.stderr); sys.exit(1)
src = src.replace(LAYOUT_NEEDLE, LAYOUT_REPL, 1)

open(path, "w").write(src)
print("✓ index.ts (secondary-right-render)")
PYIDX

# ── 7. Mode-aware border colors (green=plan, red=build) ──────────────────
python3 - "$PKG/index.ts" <<'PYBORDERCOLOR'
import re, sys
path = sys.argv[1]
src = open(path).read()

HELPER = '''
  // [pi-config patch:mode-border-color]
  function getModeBorderFn(theme: Theme): (s: string) => string {
    try {
      const status = footerDataRef?.getExtensionStatuses().get("vim-mode") ?? "";
      if (status.includes("NORMAL")) return (s: string) => theme.fg("success", s);
      if (status.includes("INSERT")) return (s: string) => theme.fg("thinkingLow", s);
      if (status.includes("VISUAL")) return (s: string) => theme.fg("warning", s);
    } catch { /* fallthrough */ }
    return (s: string) => theme.fg("borderMuted", s);
  }
'''

if "[pi-config patch:mode-border-color]" not in src:
    marker = '  function renderPowerlineStatusLines(width: number): string[] {'
    if marker not in src:
        print('index.ts: helper anchor not found', file=sys.stderr); sys.exit(1)
    src = src.replace(marker, HELPER + '\n' + marker, 1)

# Accept either freshly-rounded functions or older mode-border versions.
src, n1 = re.subn(
    r'const border = \(s: string\) => theme\.fg\("borderMuted", s\);\n(\s*const inner = layout\.topContent;)',
    r'const border = getModeBorderFn(theme);\n\1',
    src,
    count=1,
)
src, n2 = re.subn(
    r'const border = \(s: string\) => theme\.fg\("borderMuted", s\);\n(\s*const left = layout\.secondaryContent \|\| "";)',
    r'const border = getModeBorderFn(theme);\n\1',
    src,
    count=1,
)
# Older script variant used getModeBorderColor(); normalize that too.
src = src.replace('const border = (s: string) => theme.fg(getModeBorderColor(), s);', 'const border = getModeBorderFn(theme);')

if 'const border = getModeBorderFn(theme);' not in src:
    print('index.ts: mode border replacement not found', file=sys.stderr); sys.exit(1)

open(path, "w").write(src)
print("✓ index.ts (mode-border-color)")
PYBORDERCOLOR

# ── 8. Wire vim mode status + cursor shape into powerline editor factory ─────
python3 - "$PKG/index.ts" <<'PYVIMWIRE'
import sys
path = sys.argv[1]
src = open(path).read()
changes = 0

# 8a. Publish vim mode + initial cursor
if "[pi-config patch:vim-mode-wire]" not in src:
    N = "      currentEditor = editor;"
    R = '''      currentEditor = editor;
      // [pi-config patch:vim-mode-wire] Publish vim mode to powerline status
      if (typeof editor.setModeChangeCallback === "function") {
        const publishVimMode = (mode: string) => {
          const label = mode.toUpperCase();
          const color = label === "NORMAL" ? "success"
            : label.startsWith("VISUAL") ? "warning"
            : "thinkingLow";
          ctx.ui.setStatus("vim-mode", ctx.ui.theme.fg(color, `\u25cf ${label}`));
        };
        editor.setModeChangeCallback(publishVimMode);
        publishVimMode("insert");
        process.stdout.write("\\x1b[6 q");
      }'''
    if N not in src:
        print("vim-mode-wire: needle not found", file=sys.stderr); sys.exit(1)
    src = src.replace(N, R, 1)
    changes += 1
else:
    print("✓ index.ts (vim-mode-wire already patched)")

# 8b. Reset cursor on shutdown
if "[pi-config patch:cursor-reset]" not in src:
    N2 = '  pi.on("session_shutdown", async () => {\n    sessionGeneration++;'
    R2 = '  pi.on("session_shutdown", async () => {\n    // [pi-config patch:cursor-reset] Reset cursor shape to default on exit\n    process.stdout.write("\\x1b[0 q");\n    sessionGeneration++;'
    if N2 not in src:
        print("cursor-reset: needle not found", file=sys.stderr); sys.exit(1)
    src = src.replace(N2, R2, 1)
    changes += 1
else:
    print("✓ index.ts (cursor-reset already patched)")

if changes:
    open(path, 'w').write(src)
    print(f"✓ index.ts ({changes} vim/cursor patches)")
PYVIMWIRE

# ── 9. Remove powerline's own editor border lines (rounded borders are enough) ─
python3 - "$PKG/index.ts" <<'PYNOLINES'
import sys
path = sys.argv[1]
src = open(path).read()

if "[pi-config patch:no-editor-lines]" in src:
    print("✓ index.ts (no-editor-lines already patched)")
    sys.exit(0)

N1 = '''        const result: string[] = [];
        result.push(" " + bc("─".repeat(width - 2)));'''
R1 = '''        const result: string[] = [];
        // [pi-config patch:no-editor-lines] suppressed — powerline rounded borders are enough
        result.push(" ".repeat(width));'''

N2 = '''        result.push(" " + bc("─".repeat(width - 2)));

        for (let i = bottomBorderIndex + 1; i < lines.length; i++) {'''
R2 = '''        result.push(" ".repeat(width));

        for (let i = bottomBorderIndex + 1; i < lines.length; i++) {'''

if N1 not in src:
    print("no-editor-lines: top needle not found", file=sys.stderr); sys.exit(1)
if N2 not in src:
    print("no-editor-lines: bottom needle not found", file=sys.stderr); sys.exit(1)

src = src.replace(N1, R1, 1).replace(N2, R2, 1)
open(path, 'w').write(src)
print("✓ index.ts (no-editor-lines)")
PYNOLINES

echo "Done. Restart pi (Ctrl+D then pi) to pick up the changes."

