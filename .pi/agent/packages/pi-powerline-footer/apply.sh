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
# Pi installs npm packages in its own config directory, not globally.
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

PKG="$(resolve_pkg pi-powerline-footer || true)"

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
    "    leftSegments: [\"path\"],\n"
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
# Support both old (presetDef) and new (separatorStyle) upstream signatures.
for _build_arg in ('separatorStyle', 'presetDef'):
    end_marker = f"  return {{\n    topContent: buildContentFromParts(topSegments, {_build_arg}),\n    secondaryContent: buildContentFromParts(secondarySegments, {_build_arg}),\n  }};\n}}"
    j = src.find(end_marker, i)
    if j != -1:
        break
else:
    print("Could not find return block to patch", file=sys.stderr)
    sys.exit(1)

# Detect whether mergeSegmentsWithCustomItems takes extra args (v0.15+).
if 'mergeSegmentsWithCustomItems(presetDef, config.customItems, {' in src:
    _merge_call = (
        "  const mergedSegments = mergeSegmentsWithCustomItems(presetDef, config.customItems, {\n"
        "    layout: config.layout,\n"
        "    disabledSegments: config.disabledSegments,\n"
        "  });\n"
    )
else:
    _merge_call = "  const mergedSegments = mergeSegmentsWithCustomItems(presetDef, config.customItems);\n"

replacement = (
    "  // [pi-config patch] Render primary and secondary rows independently.\n"
    "  // Stock behavior auto-promotes secondary segments to the top bar when wide;\n"
    "  // this patch keeps the user-configured split intact at any width.\n"
    + _merge_call +
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
    f"    topContent: buildContentFromParts(topSegments, {_build_arg}),\n"
    f"    secondaryContent: buildContentFromParts(secondarySegments, {_build_arg}),\n"
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
    print("\u2713 index.ts (vibe multi-word skipped: upstream already handles it)")
    sys.exit(0)

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
find_editor_js() {
  local root hit

  for root in \
    "$PKG/node_modules" \
    "${NPM_ROOT:-}" \
    "/opt/homebrew/lib/node_modules" \
    "/usr/local/lib/node_modules"; do
    [[ -n "${root:-}" && -d "$root" ]] || continue
    hit="$(find "$root" \( -path '*/@earendil-works/pi-tui/dist/components/editor.js' -o -path '*/@mariozechner/pi-tui/dist/components/editor.js' \) -print -quit 2>/dev/null || true)"
    if [[ -n "${hit:-}" ]]; then
      printf '%s\n' "$hit"
      return 0
    fi
  done

  return 1
}

EDITOR_JS="$(find_editor_js || true)"
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

# Patch renderPowerlinePrimaryLines to wrap content in ╭───╮.
# pi-powerline-footer 0.7 renamed the former "Top" renderer to "Primary".
NT = '''  function renderPowerlinePrimaryLines(width: number, theme: Theme): string[] {
    if (!currentCtx) return [];

    const layout = getResponsiveLayout(width, theme);
    return layout.topContent ? [layout.topContent] : [];
  }'''

RT = '''  // [pi-config patch:rounded-powerline]
  function renderPowerlinePrimaryLines(width: number, theme: Theme): string[] {
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

# Version 0.7 derives rows through buildRow(), so add the right-aligned
# secondary group to its returned layout instead of patching its old direct loop.
NM = '''  return {
    leftSegments: buildRow("left", layout?.left, presetDef.leftSegments),
    rightSegments: buildRow("right", layout?.right, presetDef.rightSegments),
    secondarySegments: buildRow("secondary", layout?.secondary, presetDef.secondarySegments ?? []),
  };'''
RM = '''  return {
    leftSegments: buildRow("left", layout?.left, presetDef.leftSegments),
    rightSegments: buildRow("right", layout?.right, presetDef.rightSegments),
    secondarySegments: buildRow("secondary", layout?.secondary, presetDef.secondarySegments ?? []),
    secondaryRightSegments: customItems
      .filter((item) => (item.position as string) === "secondary-right")
      .map((item) => `custom:${item.id}` as StatusLineSegmentId)
      .filter((id) => !disabled.has(id)),
  } as any;'''

for needle, repl in [(NN, RN), (NM, RM)]:
    if needle not in src:
        print("powerline-config.ts: needle not found", file=sys.stderr); sys.exit(1)
    src = src.replace(needle, repl, 1)

# Keep the declared position union aligned with the accepted configuration.
types_path = path.rsplit("/", 1)[0] + "/types.ts"
types = open(types_path).read()
types_needle = 'export type CustomItemPosition = "left" | "right" | "secondary";'
types_repl = 'export type CustomItemPosition = "left" | "right" | "secondary" | "secondary-right"; // [pi-config patch:secondary-right]'
if types_needle in types:
    open(types_path, "w").write(types.replace(types_needle, types_repl, 1))
elif "[pi-config patch:secondary-right]" not in types:
    print("types.ts: CustomItemPosition needle not found", file=sys.stderr); sys.exit(1)

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
# Try both separatorStyle (v0.15+) and presetDef (older) since step 3 may have used either
for _ba in ('separatorStyle', 'presetDef'):
    LAYOUT_NEEDLE = f'''  const topSegments = renderRow(primaryIds);
  const secondarySegments = renderRow(secondaryIds);
  return {{
    topContent: buildContentFromParts(topSegments, {_ba}),
    secondaryContent: buildContentFromParts(secondarySegments, {_ba}),
  }};
}}'''
    if LAYOUT_NEEDLE in src:
        LAYOUT_REPL = f'''  const topSegments = renderRow(primaryIds);
  const secondarySegments = renderRow(secondaryIds);
  const secondaryRightIds = (mergedSegments as any).secondaryRightSegments || [];
  const secondaryRightSegments = renderRow(secondaryRightIds);
  return {{
    topContent: buildContentFromParts(topSegments, {_ba}),
    secondaryContent: buildContentFromParts(secondarySegments, {_ba}),
    secondaryRightContent: buildContentFromParts(secondaryRightSegments, {_ba}),
  }} as any;
}}'''
        break
else:
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
      if (status.includes("INSERT")) { const _p = ansi.getFgAnsi(198, 120, 221); return (s: string) => _p + s + "\\x1b[39m"; }
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
          // [pi-config patch:vim-mode-wire-purple] INSERT uses raw ANSI purple (#c678dd)
          const _statusText = label === "NORMAL" ? ctx.ui.theme.fg("success", `\u25cf ${label}`)
            : label.startsWith("VISUAL") ? ctx.ui.theme.fg("warning", `\u25cf ${label}`)
            : (() => { const _p = ansi.getFgAnsi(198, 120, 221); return `${_p}\u25cf ${label}\\x1b[39m`; })();
          ctx.ui.setStatus("vim-mode", _statusText);
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
    # Match both old and new session_shutdown signatures
    for _sig in ('async (_event, ctx) => {', 'async (_event) => {', 'async (event) => {', 'async (event, ctx) => {'):
        N2 = f'  pi.on("session_shutdown", {_sig}'
        if N2 in src:
            break
    R2 = N2 + '\n    // [pi-config patch:cursor-reset] Reset cursor shape to default on exit\n    process.stdout.write("\\x1b[0 q");'
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

import re

# Match the top border line regardless of indentation depth
m1 = re.search(r'^(\s+)(const result: string\[\] = \[\];\n\s+result\.push\(" " \+ bc\("─"\.repeat\(width - 2\)\)\);)', src, re.M)
if not m1:
    print("no-editor-lines: top needle not found", file=sys.stderr); sys.exit(1)
N1 = m1.group(0)
R1 = m1.group(1) + 'const result: string[] = [];\n' + m1.group(1) + '// [pi-config patch:no-editor-lines] suppressed -- powerline rounded borders are enough\n' + m1.group(1) + 'result.push(" ".repeat(width));'

# Match the bottom border line followed by the for-loop
m2 = re.search(r'^(\s+)(result\.push\(" " \+ bc\("─"\.repeat\(width - 2\)\)\);\n\n\s+for \(let i = bottomBorderIndex \+ 1; i < lines\.length; i\+\+\) \{)', src, re.M)
if not m2:
    print("no-editor-lines: bottom needle not found", file=sys.stderr); sys.exit(1)
N2 = m2.group(0)
R2 = m2.group(1) + 'result.push(" ".repeat(width));\n\n' + m2.group(1) + 'for (let i = bottomBorderIndex + 1; i < lines.length; i++) {'

src = src.replace(N1, R1, 1).replace(N2, R2, 1)
open(path, 'w').write(src)
print("✓ index.ts (no-editor-lines)")
PYNOLINES

# ── 10. vim-mode-aware prompt glyph (> changes color with mode) ─────────────
python3 - "$PKG/index.ts" <<'PYVIMPROMPT'
import re, sys
path = sys.argv[1]
src = open(path).read()

if "[pi-config patch:vim-mode-prompt-glyph]" in src:
    print("✓ index.ts (vim-mode-prompt-glyph already patched)")
    sys.exit(0)

# Match both old (U+276F + inline color) and new (> + separate promptColor) upstream
_old_pat = (
    '        const bc = (s: string) => `${getFgAnsiCode("sep")}${s}${ansi.reset}`;\n'
    '        const promptGlyph = bashModeActive ? "$" : "\u276f";\n'
    '        const prompt = `${ansi.getFgAnsi(152, 195, 121)}${promptGlyph}${ansi.reset}`;'
)
_new_pat = re.compile(
    r'([ \t]+)(const bc = \(s: string\) => [^;]+;\n)'
    r'(\s+const promptGlyph = bashModeActive \? "\$" : ">";\n)'
    r'(\s+const promptColor = [^;]+;\n)'
    r'(\s+const prompt = [^;]+;)'
)

def _build_repl(indent, bc_line, glyph_line):
    return (
        bc_line
        + glyph_line
        + f'{indent}// [pi-config patch:vim-mode-prompt-glyph]\n'
        f'{indent}const _vimSt = footerDataRef?.getExtensionStatuses().get("vim-mode") ?? "";\n'
        f'{indent}const _promptRgb = _vimSt.includes("INSERT") ? ansi.getFgAnsi(198, 120, 221)\n'
        f'{indent}  : _vimSt.includes("VISUAL") ? ansi.getFgAnsi(229, 192, 123)\n'
        f'{indent}  : ansi.getFgAnsi(152, 195, 121);\n'
        f'{indent}const prompt = `${{_promptRgb}}${{promptGlyph}}${{ansi.reset}}`;'
    )

if _old_pat in src:
    _r = _build_repl(
        '        ',
        '        const bc = (s: string) => `${getFgAnsiCode("sep")}${s}${ansi.reset}`;\n',
        '        const promptGlyph = bashModeActive ? "$" : "\u276f";\n',
    )
    src = src.replace(_old_pat, _r, 1)
elif (_m := _new_pat.search(src)):
    _r = _build_repl(_m.group(1), _m.group(1) + _m.group(2), _m.group(3))
    src = src.replace(_m.group(0), _r, 1)
else:
    print("vim-mode-prompt-glyph: needle not found -- skipping", file=sys.stderr)
    sys.exit(0)

open(path, 'w').write(src)
print("✓ index.ts (vim-mode-prompt-glyph)")
PYVIMPROMPT

# ── 11. Fixed-editor custom shortcuts: scroll three lines ───────────────────
# The fixed-editor directory was removed in pi-powerline-footer >= 0.15.
# Skip gracefully when the file does not exist.
SCROLL_FILE="$PKG/fixed-editor/terminal-split.ts"
if [[ ! -f "$SCROLL_FILE" ]]; then
  echo "✓ terminal-split.ts (skipped: fixed-editor removed in this version)"
else
python3 - "$SCROLL_FILE" <<'PYSCROLLLINES'
import sys
path = sys.argv[1]
src = open(path).read()

if "[pi-config patch:custom-scroll-lines]" in src:
    print("✓ terminal-split.ts (custom scroll lines already patched)")
    sys.exit(0)

NEEDLE = '''  if (shortcuts.up && (
    matchesConfiguredShortcut(data, shortcuts.up)
    || matchesKey(data, "pageUp")
    || matchesKey(data, "ctrl+shift+up")
    || /^\\x1b\\[(?:5;9(?::[12])?~|1;6(?::[12])?A|57421;9(?::[12])?u|57419;6(?::[12])?u)$/.test(data)
  )) return 10;
  if (shortcuts.down && (
    matchesConfiguredShortcut(data, shortcuts.down)
    || matchesKey(data, "pageDown")
    || matchesKey(data, "ctrl+shift+down")
    || /^\\x1b\\[(?:6;9(?::[12])?~|1;6(?::[12])?B|57422;9(?::[12])?u|57420;6(?::[12])?u)$/.test(data)
  )) return -10;'''

REPL = '''  // [pi-config patch:custom-scroll-lines] Custom shortcuts move three lines;
  // page-based shortcuts keep the package's existing ten-line behavior.
  if (shortcuts.up && matchesConfiguredShortcut(data, shortcuts.up)) return 3;
  if (shortcuts.down && matchesConfiguredShortcut(data, shortcuts.down)) return -3;
  if (shortcuts.up && (
    matchesKey(data, "pageUp")
    || matchesKey(data, "ctrl+shift+up")
    || /^\\x1b\\[(?:5;9(?::[12])?~|1;6(?::[12])?A|57421;9(?::[12])?u|57419;6(?::[12])?u)$/.test(data)
  )) return 10;
  if (shortcuts.down && (
    matchesKey(data, "pageDown")
    || matchesKey(data, "ctrl+shift+down")
    || /^\\x1b\\[(?:6;9(?::[12])?~|1;6(?::[12])?B|57422;9(?::[12])?u|57420;6(?::[12])?u)$/.test(data)
  )) return -10;'''

if NEEDLE not in src:
    print("terminal-split.ts: keyboard scroll needle not found", file=sys.stderr)
    sys.exit(1)

open(path, "w").write(src.replace(NEEDLE, REPL, 1))
print("✓ terminal-split.ts (custom shortcuts scroll three lines)")
PYSCROLLLINES
fi

echo "Done. Restart pi (Ctrl+D then pi) to pick up the changes."
