#!/usr/bin/env bash
# Patch vim-motions-pi to extend BashModeEditor (from pi-powerline-footer)
# instead of CustomEditor, and patch powerline to use VimEditor in its factory.
#
# Re-run after `pi update` / `pi install`.

set -euo pipefail

VIM_PKG="/opt/homebrew/lib/node_modules/vim-motions-pi"
PL_PKG="/opt/homebrew/lib/node_modules/pi-powerline-footer"

[[ -d "${VIM_PKG:-}" ]] || { echo "vim-motions-pi not found" >&2; exit 1; }
[[ -d "${PL_PKG:-}" ]] || { echo "pi-powerline-footer not found" >&2; exit 1; }

echo "→ vim-motions-pi: $VIM_PKG"
echo "→ pi-powerline-footer: $PL_PKG"

# ── 1. Patch VimEditor to extend BashModeEditor ──────────────────────────────
python3 - "$VIM_PKG/extensions/vim-motion.ts" "$PL_PKG" <<'PY'
import sys
path = sys.argv[1]
pl_pkg = sys.argv[2]
src = open(path).read()

if "[pi-config patch:vim-bash-merge]" in src:
    print("✓ vim-motion.ts (already patched)")
    sys.exit(0)

# 1a. Add BashModeEditor import
OLD_IMPORT = 'import { CustomEditor, type ExtensionAPI } from "@mariozechner/pi-coding-agent";'
# Try both vendor names
if OLD_IMPORT not in src:
    OLD_IMPORT = 'import { CustomEditor, type ExtensionAPI } from "@earendil-works/pi-coding-agent";'
if OLD_IMPORT not in src:
    print("Could not find CustomEditor import", file=sys.stderr); sys.exit(1)

NEW_IMPORT = (
    f'// [pi-config patch:vim-bash-merge]\n'
    f'import {{ BashModeEditor }} from "{pl_pkg}/bash-mode/editor.ts";\n'
    f'{OLD_IMPORT.replace("CustomEditor, ", "")}'
)
src = src.replace(OLD_IMPORT, NEW_IMPORT, 1)

# 1b. Change extends clause
src = src.replace(
    'class VimEditor extends CustomEditor {',
    'class VimEditor extends BashModeEditor {',
    1
)

# 1c. Prevent vim from calling setEditorComponent — powerline will do it.
# Instead, export VimEditor so powerline can import it.
OLD_SESSION = '''	pi.on("session_start", (_event, ctx) => {
		ctx.ui.setEditorComponent((tui, theme, keybindings) => new VimEditor(tui, theme, keybindings));
		ctx.ui.notify(clipboardStatusMessage(), "info");
	});'''

NEW_SESSION = '''	// [pi-config patch:vim-bash-merge] Don't call setEditorComponent —
	// powerline does it with VimEditor injected into its factory.
	pi.on("session_start", (_event, ctx) => {
		ctx.ui.notify(clipboardStatusMessage(), "info");
	});'''

if OLD_SESSION not in src:
    print("Could not find session_start block", file=sys.stderr); sys.exit(1)
src = src.replace(OLD_SESSION, NEW_SESSION, 1)

# 1d. Export VimEditor class
src = src.replace('class VimEditor extends BashModeEditor {', 'export class VimEditor extends BashModeEditor {', 1)

open(path, 'w').write(src)
print("✓ vim-motion.ts (extends BashModeEditor, exported)")
PY

# ── 2. Patch powerline to use VimEditor instead of BashModeEditor ─────────────
python3 - "$PL_PKG/index.ts" "$VIM_PKG" <<'PY2'
import sys
path = sys.argv[1]
vim_pkg = sys.argv[2]
src = open(path).read()

if "[pi-config patch:vim-in-powerline]" in src:
    print("✓ index.ts (vim-in-powerline already patched)")
    sys.exit(0)

# 2a. Add VimEditor import near BashModeEditor import
BASH_IMPORT = 'import { BashModeEditor } from "./bash-mode/editor.ts";'
if BASH_IMPORT not in src:
    BASH_IMPORT = 'import { BashModeEditor } from "./bash-mode/editor.js";'
if BASH_IMPORT not in src:
    print("Could not find BashModeEditor import", file=sys.stderr); sys.exit(1)

NEW_IMPORT = (
    f'{BASH_IMPORT}\n'
    f'// [pi-config patch:vim-in-powerline]\n'
    f'import {{ VimEditor }} from "{vim_pkg}/extensions/vim-motion.ts";'
)
src = src.replace(BASH_IMPORT, NEW_IMPORT, 1)

# 2b. Replace `new BashModeEditor(` with `new VimEditor(` in the editor factory
src = src.replace(
    'const editor = new BashModeEditor(tui, editorTheme, keybindings, {',
    'const editor = new VimEditor(tui, editorTheme, keybindings, {',
    1
)

open(path, 'w').write(src)
print("✓ index.ts (uses VimEditor in factory)")
PY2

# ── 3. Add arrow key passthrough + mode change callback ─────────────────
python3 - "$VIM_PKG/extensions/vim-motion.ts" <<'PY3'
import sys
path = sys.argv[1]
src = open(path).read()

if "[pi-config patch:vim-mode-status]" in src:
    print("✓ vim-motion.ts (arrows + mode callback already patched)")
    sys.exit(0)

# Arrow passthrough
OLD = 'matchesKey(data, "shift+tab");'
NEW = '''matchesKey(data, "shift+tab")
\t\t|| matchesKey(data, "up")
\t\t|| matchesKey(data, "down")
\t\t|| matchesKey(data, "left")
\t\t|| matchesKey(data, "right");'''

if OLD not in src:
    print("passthrough needle not found", file=sys.stderr); sys.exit(1)
src = src.replace(OLD, NEW, 1)

# Mode callback
OLD_MODE = '''\tprivate setMode(mode: Mode): void {
\t\tthis.mode = mode;
\t\tthis.requestRender();
\t}'''

NEW_MODE = '''\t// [pi-config patch:vim-mode-status]
\tprivate _onModeChange: ((mode: Mode) => void) | null = null;
\tsetModeChangeCallback(fn: (mode: Mode) => void): void { this._onModeChange = fn; }

\tprivate setMode(mode: Mode): void {
\t\tthis.mode = mode;
\t\tthis._onModeChange?.(mode);
\t\t// DECSCUSR: beam for insert, block for normal/visual
\t\tif (mode === "insert") {
\t\t\tprocess.stdout.write("\\x1b[6 q");
\t\t} else {
\t\t\tprocess.stdout.write("\\x1b[2 q");
\t\t}
\t\tthis.requestRender();
\t}'''

if OLD_MODE not in src:
    print("setMode needle not found", file=sys.stderr); sys.exit(1)
src = src.replace(OLD_MODE, NEW_MODE, 1)

open(path, 'w').write(src)
print("✓ vim-motion.ts (arrows + mode callback)")
PY3

echo "Done. Restart pi (Ctrl+D then pi) to pick up."
