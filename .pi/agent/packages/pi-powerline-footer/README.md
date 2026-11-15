# pi-powerline-footer custom configuration

Portable customizations for `pi-powerline-footer` **0.21.x**, applied after npm package updates on macOS or Linux.

## Result

- Top row: agent mode and path on the left; model, thinking level, and context on the right
- Bottom row: Git and shell mode on the left; Vim mode on the right
- Fixed rows: segments never migrate between the top and bottom bars
- Rounded frame whose color follows Vim mode
- Vim-colored prompt and cursor shape
- No idle editor border lines; an active embedded working status is preserved
- OneDark colors and thin Powerline separators

## Requirements

- `pi-powerline-footer` 0.21.x
- `vim-motions-pi` 0.1.4
- Node.js and npm (already required by Pi)

No GNU-specific commands or Python installation are required. The package resolver supports Homebrew/npm paths on macOS and the standard npm/Pi package paths on Linux.

## Apply

Run after installing or updating either npm package:

```bash
~/.pi/agent/packages/pi-powerline-footer/apply.sh
```

Then run `/reload` in Pi or restart it.

The script is idempotent and fails before writing if the installed Powerline source is unsupported. It also installs `theme.json` in the durable user override directory:

```text
${PI_CODING_AGENT_DIR:-~/.pi/agent}/extensions/powerline-footer/theme.json
```

For isolated testing, override package locations:

```bash
PI_POWERLINE_FOOTER_DIR=/path/to/pi-powerline-footer \
VIM_MOTIONS_DIR=/path/to/vim-motions-pi \
PI_CODING_AGENT_DIR=/tmp/pi-agent \
~/.pi/agent/packages/pi-powerline-footer/apply.sh
```

## Files

- `apply.sh` — portable package discovery and theme installation
- `patch.mjs` — validated, atomic source transformations for 0.21.x
- `theme.json` — OneDark semantic colors
