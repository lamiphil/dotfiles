# pi-powerline-footer overrides

The plugin reads its theme and segment presets from inside its own npm package
directory (e.g. `/opt/homebrew/lib/node_modules/pi-powerline-footer/`). Those
files get **wiped on `pi update` / `pi install`**, so we keep the source-of-
truth here in dotfiles and re-apply with one command.

## Files

- `theme.json`  — OneDark Pro color override (model purple, path cyan, etc.).
- `apply.sh`    — Applies all customizations:
  1. Drops `theme.json` into the package dir.
  2. Patches `presets.ts` so the `default` preset puts only `model`, `thinking`,
     and `path` on the **top row**, with everything else on the **secondary
     (bottom) row**.
  3. Patches `index.ts → computeResponsiveLayout()` so secondary segments stay
     on the bottom row instead of being auto-promoted to the top when the
     terminal is wide.

## Usage

After installing or updating pi-powerline-footer:

```bash
~/dotfiles/.pi/agent/packages/pi-powerline-footer/apply.sh
```

Then `/reload` in pi.

The script is idempotent — running it twice is safe (the patch markers in
`index.ts` ensure a second pass finds nothing to do, the python regex on
`presets.ts` always rewrites the whole `default` block).
