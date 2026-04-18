# Dotfiles Repository

Personal dotfiles for Philippe Lamy (`lamiphil`), managed with **GNU Stow**.

## Quick Reference

- **Apply configs**: `stow .` from repo root
- **Platforms**: Arch Linux (primary), macOS, Ubuntu/Debian
- **Editor**: Neovim (Kickstart.nvim-based)
- **Shell**: Bash with Starship prompt
- **Terminal**: Ghostty (all platforms)
- **Keyboard layout**: Colemak-DH

## Repository Structure

```
dotfiles/
├── .config/                # XDG configs
│   ├── nvim/               # Neovim (Kickstart.nvim + lazy.nvim)
│   ├── tmux/               # Tmux (prefix: Ctrl+Space)
│   ├── ghostty/            # Terminal (OneDark-Pro theme)
│   ├── hypr/               # Hyprland WM (Linux)
│   ├── aerospace/          # AeroSpace WM (macOS)
│   ├── waybar/             # Status bar (Linux)
│   ├── opencode/           # OpenCode AI tool (MCP servers)
│   ├── yazi/               # File manager
│   ├── k9s/                # Kubernetes TUI
│   ├── rofi/               # App launcher (Linux)
│   ├── wal/                # Pywal color templates
│   ├── obsidian/           # Shared Obsidian vault config
│   ├── television/         # TV fuzzy finder
│   └── lazygit/            # Git TUI
├── .bash_profile           # Login shell → sources .bashrc
├── .bashrc                 # Interactive shell (sources all .bash_* files)
├── .bash_env               # Environment variables (EDITOR, locale, GTK)
├── .bash_aliases           # Command shortcuts
├── .bash_functions         # Shell functions (yazi, AWS)
├── .gitconfig              # Git user + short aliases
├── starship.toml           # Starship prompt (k8s context, cloud, git)
├── .agents/                # AI agent skills
├── scripts/                # Platform install scripts (not stowed)
└── wallpapers/             # Desktop wallpapers (not stowed)
```

## Stow Conventions

Files in `.stow-local-ignore` are **not symlinked** to `$HOME`:
- `scripts/`, `repos/`, `README.*`, `.git*`, `CLAUDE.md`

Everything else gets symlinked when running `stow .`

## Neovim Configuration

Built on **Kickstart.nvim** with **lazy.nvim** plugin manager.

```
.config/nvim/
├── init.lua                  # Core config (options, keymaps, plugins)
├── lua/
│   ├── kickstart/plugins/    # Optional kickstart modules (autopairs, gitsigns)
│   └── custom/plugins/       # Personal plugin configs
│       ├── lualine.lua       # Statusline
│       ├── vim-tmux-navigator.lua
│       ├── markview.lua      # Markdown rendering
│       ├── noice.lua         # UI enhancements
│       ├── snacks-dashboard.lua  # Start screen
│       ├── tv.lua            # Television fuzzy finder
│       ├── yazi.lua          # File manager
│       ├── lazygit.lua       # Git TUI
│       ├── opencode.lua      # AI assistant
│       └── nvim-ts-autotag.lua
└── doc/                      # Kickstart help docs
```

**Colorscheme**: onedark (dark style)

**LSP servers**: lua_ls, html, cssls, pyright, ts_ls, tailwindcss, eslint, stylua

**Key conventions**:
- Leader: `<Space>`
- `jk` to escape insert mode
- `H`/`L` to jump to line start/end
- `<leader>sf` find files, `<leader>sg` grep, `<leader>s.` recent files
- `<leader>sv`/`sh` vertical/horizontal split
- `<C-h/j/k/l>` navigate splits (via vim-tmux-navigator)
- `+`/`-` increment/decrement
- Telescope shows hidden files by default, `<C-h>` toggles

**Adding a plugin**: Create a file in `lua/custom/plugins/` returning a lazy.nvim spec.

**Adding keymaps/options**: Edit `init.lua` directly (kickstart philosophy).

## Shell Configuration

**Load order**: `.bash_profile` → `.bashrc` → `.bash_env` → `.bash_aliases` → `.bash_functions` → `.env` (secrets, gitignored)

| File | Purpose |
|------|---------|
| `.bash_env` | Environment variables, PATH, sources `~/.env.local` for machine-specific overrides |
| `.bash_aliases` | Shortcuts: `vi`→nvim, `k`→kubectl, `lg`→lazygit, `dot`→cd dotfiles+nvim, `tf`→terraform |
| `.bash_functions` | `cd()` auto-ls, `y()` yazi wrapper, `aws-switch-profile()`, `aws-sso-login()` |

**Tools initialized in `.bashrc`**: Starship, Zoxide (`--cmd cd`), fzf (ripgrep+bat preview), ssh-agent, NVM, Pywal

**Tmux auto-start**: `.bashrc` automatically attaches to or creates a tmux session on shell launch.

## Tmux Configuration

- **Prefix**: `Ctrl+Space`
- **Plugins**: TPM, tmux-sensible, vim-tmux-navigator, tmux-dotbar, tmux-yank
- **Copy mode**: vi-mode with `v`/`y` to select/yank
- **Workspace keys**: `a/r/s/t/g/m/n` → windows 1-7 (Colemak-DH home row)
- **Session keys**: `A`=personal, `R`=work, `S`=scratch, `C`=chooser
- **Splits**: `h`/`v` horizontal/vertical (in current dir)
- **Navigation**: `Shift+Alt+H/L` prev/next window, `Ctrl+Alt+h/j/k/l` resize

## Window Managers

Hyprland (Linux) and AeroSpace (macOS) share matching keybind conventions:

| Action | Hyprland | AeroSpace |
|--------|----------|-----------|
| Modifier | Super | Alt |
| Workspaces | `Super+A/R/S/T/G/M/N` | `Alt+A/R/S/T/G/M` |
| Focus | `Super+h/j/k/l` | `Alt+h/j/k/l` |
| Move window | `Super+Shift+h/j/k/l` | `Alt+Shift+h/j/k/l` |

Workspace keys use the **Colemak-DH home row** — consistent across tmux, Hyprland, and AeroSpace.

## Theming

- **OneDark** is the base theme across Neovim, Ghostty, and OpenCode TUI
- **Pywal** generates coordinated colors for Hyprland, Waybar, Rofi, and tmux dotbar
- Pywal templates are in `.config/wal/`

## Platform-Specific Configs

| Config | macOS | Linux |
|--------|-------|-------|
| Terminal | Ghostty | Ghostty |
| Window Manager | AeroSpace | Hyprland |
| Status bar | — | Waybar |
| App launcher | — | Rofi |
| Install scripts | `scripts/osx/Brewfile` | `scripts/arch/install_packages.sh`, `scripts/ubuntu/install_packages.sh` |

## Key Tools Configured

**Development**: Neovim, Git, Lazygit, fzf, ripgrep, bat, zoxide, lsd
**Containers/K8s**: Docker, kubectl, k9s, Terraform
**Cloud**: AWS CLI (with SSO functions), GitHub CLI
**Terminal**: Tmux, Starship, Yazi, Television
**AI**: OpenCode (with Grafana, GitHub, Linear MCP servers)

## Making Changes

1. **Prefer editing existing files** over creating new ones
2. **Test changes** by sourcing configs or restarting the application
3. **Platform awareness**: Check if change is platform-specific (Linux vs macOS)
4. For Neovim: restart or `:Lazy reload` after plugin changes

## Common Tasks

| Task | Location |
|------|----------|
| Add shell alias | `.bash_aliases` |
| Add shell function | `.bash_functions` |
| Add env variable | `.bash_env` |
| Add vim option/keymap | `.config/nvim/init.lua` |
| Add vim plugin | `.config/nvim/lua/custom/plugins/<name>.lua` |
| Add Hyprland keybind | `.config/hypr/hyprland.conf` |
| Add tmux keybind | `.config/tmux/tmux.conf` |

## Commit Message Convention

Format: `SCOPE - Description`

- **SCOPE**: Uppercase, represents the tool/config (NVIM, BASH, TMUX, HYPR, GIT, OSX, ARCH, etc.)
- **Separator**: ` - ` (space-dash-space)
- **Description**: Sentence case, concise
- **Language**: French or English (both used)

Examples:
```
NVIM - Migrated from NvChad to Kickstart.nvim
BASH - Ignore ZSH message on new shell
HYPR - Fix ouverture discord sur workspace 4
OPENCODE - Added config for Grafana & Github MCPs
```

## AI Agent Skills

Custom skills in `.agents/skills/`:

| Skill | Purpose |
|-------|---------|
| `commit` | Git commit with conventional commits format |
| `explorer` | Codebase exploration and teaching |
| `log` | Progress logging to notes |
| `pull` | Git pull across repos |
| `find-skills` | Discover and install skills from skills.sh |
| `skill-creator` | Create new skills |
| `logging-best-practices` | Wide events / canonical log lines patterns |

Each skill has a `SKILL.md` with frontmatter (name, description, tools) and instructions.
