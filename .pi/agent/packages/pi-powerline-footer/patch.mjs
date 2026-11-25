#!/usr/bin/env node

import { readFileSync, renameSync, writeFileSync } from "node:fs";
import { basename, dirname, join, resolve } from "node:path";

const [packageArg, vimFileArg] = process.argv.slice(2);
if (!packageArg || !vimFileArg) {
  console.error("Usage: node patch.mjs <pi-powerline-footer-dir> <vim-motion.ts>");
  process.exit(2);
}

const packageDir = resolve(packageArg);
const vimFile = resolve(vimFileArg);
const files = {
  package: join(packageDir, "package.json"),
  presets: join(packageDir, "presets.ts"),
  types: join(packageDir, "types.ts"),
  config: join(packageDir, "powerline-config.ts"),
  index: join(packageDir, "index.ts"),
  vim: vimFile,
};

const source = new Map(Object.values(files).map((file) => [file, readFileSync(file, "utf8")]));
const changed = new Set();

function get(file) {
  return source.get(file);
}

function set(file, value) {
  if (value !== get(file)) {
    source.set(file, value);
    changed.add(file);
  }
}

function replaceRequired(file, search, replacement, label) {
  const text = get(file);
  if (!text.includes(search)) {
    throw new Error(`${label}: expected source was not found in ${file}`);
  }
  set(file, text.replace(search, replacement));
}

function replaceRangeRequired(file, start, end, replacement, label) {
  const text = get(file);
  const startIndex = text.indexOf(start);
  if (startIndex < 0) throw new Error(`${label}: start anchor was not found in ${file}`);
  const endIndex = text.indexOf(end, startIndex + start.length);
  if (endIndex < 0) throw new Error(`${label}: end anchor was not found in ${file}`);
  set(file, text.slice(0, startIndex) + replacement + text.slice(endIndex));
}

const packageJson = JSON.parse(get(files.package));
if (packageJson.name !== "pi-powerline-footer") {
  throw new Error(`Unexpected package at ${packageDir}`);
}
if (!/^0\.21\./.test(packageJson.version)) {
  throw new Error(`Unsupported pi-powerline-footer version ${packageJson.version}; expected 0.21.x`);
}

// Keep the intended two-row layout stable instead of inheriting upstream preset changes.
{
  const text = get(files.presets);
  const start = text.indexOf("  default: {");
  const end = text.indexOf("\n\n  minimal: {", start);
  if (start < 0 || end < 0) throw new Error("default preset anchors were not found");
  const preset = `  default: {
    leftSegments: ["path"],
    rightSegments: ["model", "thinking", "context_pct"],
    secondarySegments: ["git", "shell_mode"],
    separator: "powerline-thin",
    colors: DEFAULT_COLORS,
    segmentOptions: {
      model: { showThinkingLevel: false },
      path: { mode: "basename" },
      git: { showBranch: true, showStaged: true, showUnstaged: true, showUntracked: true },
    },
  },`;
  set(files.presets, text.slice(0, start) + preset + text.slice(end));
}

// Add a dedicated bottom-right custom-item position.
if (!get(files.types).includes("[pi-config patch:secondary-right-types-v021]")) {
  replaceRequired(
    files.types,
    'export type CustomItemPosition = "left" | "right" | "secondary";',
    '// [pi-config patch:secondary-right-types-v021]\nexport type CustomItemPosition = "left" | "right" | "secondary" | "secondary-right";',
    "secondary-right type",
  );
}

if (!get(files.config).includes("[pi-config patch:secondary-right-config-v021]")) {
  replaceRequired(
    files.config,
    'function normalizeCustomItemPosition(value: unknown): CustomItemPosition {\n  if (value === "left" || value === "right" || value === "secondary") return value;\n  return "right";\n}',
    '// [pi-config patch:secondary-right-config-v021]\nfunction normalizeCustomItemPosition(value: unknown): CustomItemPosition {\n  if (value === "left" || value === "right" || value === "secondary" || value === "secondary-right") return value;\n  return "right";\n}',
    "secondary-right normalization",
  );

  replaceRequired(
    files.config,
    '  secondarySegments: StatusLineSegmentId[];\n} {',
    '  secondarySegments: StatusLineSegmentId[];\n  secondaryRightSegments: StatusLineSegmentId[];\n} {',
    "secondary-right merge return type",
  );

  replaceRequired(
    files.config,
    '    secondarySegments: buildRow("secondary", layout?.secondary, presetDef.secondarySegments ?? []),\n  };',
    '    secondarySegments: buildRow("secondary", layout?.secondary, presetDef.secondarySegments ?? []),\n    secondaryRightSegments: buildRow("secondary-right", undefined, []),\n  };',
    "secondary-right merge result",
  );
}

// Rewire vim-motions-pi to extend the Powerline bash editor, and expose mode changes.
{
  let text = get(files.vim);
  const bashEditorImport = `import { BashModeEditor } from ${JSON.stringify(join(packageDir, "bash-mode", "editor.ts"))};`;
  if (text.includes("[pi-config patch:vim-bash-merge]")) {
    text = text.replace(
      /\/\/ \[pi-config patch:vim-bash-merge\]\nimport \{ BashModeEditor \} from [^;]+;/,
      `// [pi-config patch:vim-bash-merge]\n${bashEditorImport}`,
    );
  } else {
    const originalImport = 'import { CustomEditor, type ExtensionAPI } from "@mariozechner/pi-coding-agent";';
    if (!text.includes(originalImport)) throw new Error("vim CustomEditor import was not found");
    text = text.replace(
      originalImport,
      `// [pi-config patch:vim-bash-merge]\n${bashEditorImport}\nimport { type ExtensionAPI } from "@mariozechner/pi-coding-agent";`,
    );
  }
  // Normalize partially patched installations left by older apply.sh versions.
  text = text.replace(/\bCustomEditor\b/g, "BashModeEditor");
  text = text.replace(/^class VimEditor extends BashModeEditor/m, "export class VimEditor extends BashModeEditor");
  text = text.replace(/^export export class VimEditor/m, "export class VimEditor");

  if (!text.includes("[pi-config patch:vim-mode-status]")) {
    const modeSetter = '\tprivate setMode(mode: Mode): void {';
    if (!text.includes(modeSetter)) throw new Error("vim setMode method was not found");
    text = text.replace(
      modeSetter,
      '\t// [pi-config patch:vim-mode-status]\n\tprivate _onModeChange: ((mode: Mode) => void) | null = null;\n\tsetModeChangeCallback(fn: (mode: Mode) => void): void { this._onModeChange = fn; }\n\n\tprivate setMode(mode: Mode): void {',
    );
  }

  const modeBlock = /\t\/\/ \[pi-config patch:vim-mode-status\]\n\tprivate _onModeChange: \(\(mode: Mode\) => void\) \| null = null;\n\tsetModeChangeCallback\(fn: \(mode: Mode\) => void\): void \{ this\._onModeChange = fn; \}\n\n\tprivate setMode\(mode: Mode\): void \{[\s\S]*?\n\t\}\n\n\tprivate setCursorIndex/;
  if (!modeBlock.test(text)) throw new Error("patched vim setMode block was not found");
  text = text.replace(
    modeBlock,
    `\t// [pi-config patch:vim-mode-status]
\tprivate _onModeChange: ((mode: Mode) => void) | null = null;
\tsetModeChangeCallback(fn: (mode: Mode) => void): void { this._onModeChange = fn; }

\tprivate setMode(mode: Mode): void {
\t\tthis.mode = mode;
\t\tthis._onModeChange?.(mode);
\t\t// DECSCUSR: beam for insert, block for normal/visual.
\t\tif (process.stdout.isTTY) {
\t\t\tprocess.stdout.write(mode === "insert" ? "\\x1b[6 q" : "\\x1b[2 q");
\t\t}
\t\tthis.requestRender();
\t}

\tprivate setCursorIndex`,
  );
  text = text.replace('private enterVisual(linewise = false): void {\n\t\tthis.mode = linewise ? "visual-line" : "visual";', 'private enterVisual(linewise = false): void {\n\t\tthis.setMode(linewise ? "visual-line" : "visual");');
  text = text.replace('private exitVisual(): void {\n\t\tthis.mode = "normal";', 'private exitVisual(): void {\n\t\tthis.setMode("normal");');
  text = text.replace('\t\t\tif (data === "V") {\n\t\t\t\tthis.mode = "visual-line";', '\t\t\tif (data === "V") {\n\t\t\t\tthis.setMode("visual-line");');
  set(files.vim, text);
}

// Import the patched Vim editor from this machine's npm installation.
{
  let text = get(files.index);
  const vimImport = `import { VimEditor } from ${JSON.stringify(vimFile)};`;
  if (text.includes("[pi-config patch:vim-in-powerline]")) {
    text = text.replace(
      /\/\/ \[pi-config patch:vim-in-powerline\]\nimport \{ VimEditor \} from [^;]+;/,
      `// [pi-config patch:vim-in-powerline]\n${vimImport}`,
    );
  } else {
    const bashImport = 'import { BashModeEditor, isPrintableInput } from "./bash-mode/editor.ts";';
    if (!text.includes(bashImport)) throw new Error("Powerline BashModeEditor import was not found");
    text = text.replace(bashImport, `${bashImport}\n// [pi-config patch:vim-in-powerline]\n${vimImport}`);
  }
  text = text.replace("const editor = new BashModeEditor(tui, editorTheme, keybindings, {", "const editor = new VimEditor(tui, editorTheme, keybindings, {");
  set(files.index, text);
}

// Replace upstream's row-promoting responsive algorithm with fixed aligned rows.
if (!get(files.index).includes("[pi-config patch:fixed-layout-v021]")) {
  const layoutBlock = `// [pi-config patch:fixed-layout-v021]
type VimModeName = "insert" | "normal" | "visual" | "visual-line";
type ResponsiveSegmentGroups = {
  leftIds: StatusLineSegmentId[];
  rightIds: StatusLineSegmentId[];
  secondaryIds: StatusLineSegmentId[];
  secondaryRightIds: StatusLineSegmentId[];
};
type ResponsiveLayout = { topContent: string; secondaryLines: string[] };

const VIM_MODE_COLORS: Record<VimModeName, [number, number, number]> = {
  insert: [152, 195, 121],
  normal: [198, 120, 221],
  visual: [224, 108, 117],
  "visual-line": [224, 108, 117],
};
let currentVimMode: VimModeName = "insert";

function getVimModeAnsi(): string {
  const [r, g, b] = VIM_MODE_COLORS[currentVimMode];
  return ansi.getFgAnsi(r, g, b);
}

function powerlineBorder(text: string): string {
  return \`\${getVimModeAnsi()}\${text}\${ansi.reset}\`;
}

function renderSegmentParts(ids: readonly StatusLineSegmentId[], ctx: SegmentContext): string[] {
  const parts: string[] = [];
  for (const id of ids) {
    const rendered = renderSegmentWithWidth(id, ctx);
    if (rendered.visible) parts.push(rendered.content);
  }
  return parts;
}

function fitAlignedRow(
  leftIds: readonly StatusLineSegmentId[],
  rightIds: readonly StatusLineSegmentId[],
  ctx: SegmentContext,
  separatorStyle: StatusLineSeparatorStyle,
  width: number,
  preserve: "left" | "right",
): string {
  const left = renderSegmentParts(leftIds, ctx);
  const right = renderSegmentParts(rightIds, ctx);
  const render = (parts: string[]) => buildContentFromParts(parts, separatorStyle);

  let leftContent = render(left);
  let rightContent = render(right);
  while (visibleWidth(leftContent) + visibleWidth(rightContent) > width) {
    const removable = preserve === "left" ? right : left;
    const fallback = preserve === "left" ? left : right;
    if (removable.length > 0) removable.pop();
    else if (fallback.length > 0) fallback.pop();
    else break;
    leftContent = render(left);
    rightContent = render(right);
  }

  if (!leftContent && !rightContent) return "";
  const gap = Math.max(0, width - visibleWidth(leftContent) - visibleWidth(rightContent));
  return leftContent + " ".repeat(gap) + rightContent;
}

/** Keep configured rows fixed and right-align their right-hand segments. */
function computeResponsiveLayout(
  ctx: SegmentContext,
  presetDef: ReturnType<typeof getPreset>,
  groups: ResponsiveSegmentGroups,
  availableWidth: number,
): ResponsiveLayout {
  const separatorStyle = config.separator ?? presetDef.separator;
  const innerWidth = Math.max(1, availableWidth - 2);
  const topContent = fitAlignedRow(
    groups.leftIds,
    groups.rightIds,
    ctx,
    separatorStyle,
    innerWidth,
    "left",
  );
  const secondaryContent = fitAlignedRow(
    groups.secondaryIds,
    groups.secondaryRightIds,
    ctx,
    separatorStyle,
    innerWidth,
    "right",
  );
  return { topContent, secondaryLines: secondaryContent ? [secondaryContent] : [] };
}

`;
  replaceRangeRequired(
    files.index,
    "type ResponsiveLayout = { topContent: string; secondaryLines: string[] };",
    "// ═══════════════════════════════════════════════════════════════════════════\n// Extension",
    layoutBlock,
    "v0.21 responsive layout",
  );

  replaceRequired(
    files.index,
    `    const allSegmentIds = [
      ...mergedSegments.leftSegments,
      ...mergedSegments.rightSegments,
      ...mergedSegments.secondarySegments,
    ];`,
    `    const segmentGroups: ResponsiveSegmentGroups = {
      leftIds: mergedSegments.leftSegments,
      rightIds: mergedSegments.rightSegments,
      secondaryIds: mergedSegments.secondarySegments,
      secondaryRightIds: mergedSegments.secondaryRightSegments,
    };
    const allSegmentIds = [
      ...segmentGroups.leftIds,
      ...segmentGroups.rightIds,
      ...segmentGroups.secondaryIds,
      ...segmentGroups.secondaryRightIds,
    ];`,
    "responsive segment groups",
  );
  replaceRequired(
    files.index,
    "    lastLayoutResult = computeResponsiveLayout(segmentCtx, presetDef, allSegmentIds, width);",
    "    lastLayoutResult = computeResponsiveLayout(segmentCtx, presetDef, segmentGroups, width);",
    "responsive layout call",
  );
}

// Render rounded top and bottom rows and keep Vim mode on the bottom right.
if (!get(files.index).includes("[pi-config patch:rounded-powerline-v021]")) {
  replaceRequired(
    files.index,
    `  function renderPowerlinePrimaryLines(width: number, theme: Theme): string[] {
    if (!currentCtx) return [];

    const layout = getResponsiveLayout(width, theme);
    return layout.topContent ? [layout.topContent] : [];
  }

  function renderPowerlineSecondaryLines(width: number, theme: Theme): string[] {
    if (!currentCtx) return [];

    return [...getResponsiveLayout(width, theme).secondaryLines];
  }`,
    `  // [pi-config patch:rounded-powerline-v021]
  function renderPowerlinePrimaryLines(width: number, theme: Theme): string[] {
    if (!currentCtx || width < 4) return [];

    const layout = getResponsiveLayout(width, theme);
    return layout.topContent
      ? [powerlineBorder("╭") + truncateToWidth(layout.topContent, width - 2, "…") + powerlineBorder("╮")]
      : [];
  }

  function renderPowerlineSecondaryLines(width: number, theme: Theme): string[] {
    if (!currentCtx || width < 4) return [];

    const rows = getResponsiveLayout(width, theme).secondaryLines;
    return rows.map((row, index) => {
      const last = index === rows.length - 1;
      return powerlineBorder(last ? "╰" : "│") + truncateToWidth(row, width - 2, "…") + powerlineBorder(last ? "╯" : "│");
    });
  }`,
    "rounded Powerline rendering",
  );
}

// Wire Vim mode status, border color, prompt color, and editor chrome suppression.
if (!get(files.index).includes("[pi-config patch:vim-mode-wire-v021]")) {
  replaceRequired(
    files.index,
    `      });

      let installingPowerlineAutocompleteProvider = false;`,
    `      });

      // [pi-config patch:vim-mode-wire-v021]
      const handleVimModeChange = (mode: string) => {
        if (mode !== "insert" && mode !== "normal" && mode !== "visual" && mode !== "visual-line") return;
        currentVimMode = mode;
        const label = mode === "visual-line" ? "VISUAL LINE" : mode.toUpperCase();
        ctx.ui.setStatus("vim-mode", \`\${getVimModeAnsi()} \${label} \${ansi.reset}\`);
        resetLayoutCache();
        tui.requestRender();
      };
      const setModeChangeCallback = Reflect.get(editor, "setModeChangeCallback");
      if (typeof setModeChangeCallback === "function") {
        setModeChangeCallback.call(editor, handleVimModeChange);
      }
      handleVimModeChange("insert");

      let installingPowerlineAutocompleteProvider = false;`,
    "Vim mode callback wiring",
  );

  replaceRequired(
    files.index,
    `  const border = (marker: "↑" | "↓" | "─") => {
    const text = marker === "─" ? "─".repeat(width - 2) : \`\${marker}\${"─".repeat(Math.max(0, width - 3))}\`;
    return \` \${colorEditorBorder(editor, text)}\`;
  };
  const promptGlyph = options.bashModeActive ? "$" : ">";
  const prompt = \`\${ansi.getFgAnsi(200, 200, 200)}\${promptGlyph}\${ansi.reset}\`;`,
    `  const promptGlyph = options.bashModeActive ? "$" : ">";
  const prompt = \`\${getVimModeAnsi()}\${promptGlyph}\${ansi.reset}\`;`,
    "fast editor prompt color",
  );
  replaceRequired(files.index, "  const lines = [border(viewport.hasBefore ? \"↑\" : \"─\")];", "  const lines: string[] = [];", "fast editor top border");
  replaceRequired(files.index, "  lines.push(border(viewport.hasAfter ? \"↓\" : \"─\"));\n  return lines;", "  return lines;", "fast editor bottom border");
  replaceRequired(files.index, "          const promptColor = ansi.getFgAnsi(200, 200, 200);", "          const promptColor = getVimModeAnsi();", "normal editor prompt color");

  replaceRequired(
    files.index,
    `          const result: string[] = [];
          // Reuse the editor's own top border when Pi has embedded a status in
          // it. The base render above ran at contentWidth, so an embedded line
          // has to be re-rendered at the width this frame actually uses.
          const embeddedTopBorder = editor.renderEmbeddedTopBorder(width - 2);
          result.push(" " + (embeddedTopBorder ?? colorEditorBorder(editor, "─".repeat(width - 2))));`,
    `          const result: string[] = [];
          // [pi-config patch:no-editor-lines-v021]
          // Preserve an active embedded working status, but omit idle editor rules.
          const embeddedTopBorder = editor.renderEmbeddedTopBorder(width - 2);
          if (embeddedTopBorder) result.push(" " + embeddedTopBorder);`,
    "normal editor top border",
  );
  replaceRequired(files.index, '          result.push(" " + colorEditorBorder(editor, "─".repeat(width - 2)));\n\n', "", "normal editor bottom border");

  replaceRequired(
    files.index,
    `    currentEditor = null;
    resetLayoutCache();`,
    `    currentEditor = null;
    if (process.stdout.isTTY) process.stdout.write("\\x1b[0 q");
    resetLayoutCache();`,
    "cursor reset on shutdown",
  );
}

// A stale-layout fallback must match the current result shape.
if (get(files.index).includes('lastLayoutResult = { topContent: "", secondaryLines: [] };')) {
  // Already correct for the v0.21 layout; retained as an explicit validation point.
} else {
  throw new Error("responsive layout fallback has an unexpected shape");
}

const requiredMarkers = [
  [files.types, "[pi-config patch:secondary-right-types-v021]"],
  [files.config, "[pi-config patch:secondary-right-config-v021]"],
  [files.index, "[pi-config patch:fixed-layout-v021]"],
  [files.index, "[pi-config patch:rounded-powerline-v021]"],
  [files.index, "[pi-config patch:vim-mode-wire-v021]"],
  [files.vim, "[pi-config patch:vim-mode-status]"],
];
for (const [file, marker] of requiredMarkers) {
  if (!get(file).includes(marker)) throw new Error(`validation failed: ${marker} missing from ${file}`);
}
if (get(files.vim).includes("class VimEditor extends CustomEditor")) {
  throw new Error("validation failed: VimEditor still extends CustomEditor");
}

// All source transformations succeeded. Only now replace files on disk.
for (const file of changed) {
  const temporary = join(dirname(file), `.${basename(file)}.pi-config.tmp`);
  writeFileSync(temporary, get(file));
  renameSync(temporary, file);
}

console.log(`Patched pi-powerline-footer ${packageJson.version} (${changed.size} source files changed)`);
