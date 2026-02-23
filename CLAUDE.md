# Dotfiles Repository

Personal dotfiles for Philippe Lamy, managed with **GNU Stow**.

## Quick Reference

- **Apply configs**: `stow .` from repo root
- **Platforms**: macOS, Ubuntu/Debian, Arch Linux
- **Editor**: Neovim (NvChad-based)
- **Shell**: Bash with Starship prompt
- **Terminal**: Ghostty (all platforms)

## Repository Structure

```
dotfiles/
├── .config/              # XDG configs (main application configs)
│   ├── nvim/             # Neovim (NvChad + lazy.nvim)
│   ├── tmux/             # Tmux with TPM
│   ├── ghostty/          # Terminal (all platforms)
│   ├── aerospace/        # Window manager (macOS)
│   ├── hypr/             # Hyprland WM (Linux)
│   ├── yazi/             # File manager
│   ├── k9s/              # Kubernetes TUI
│   └── ...
├── .bash_*               # Shell configuration
├── .agents/skills/       # AI agent skills
├── scripts/              # Installation scripts (not stowed)
├── wallpapers/           # Desktop wallpapers (not stowed)
└── starship.toml         # Starship prompt config
```

## Stow Conventions

Files in `.stow-local-ignore` are **not symlinked**:
- `scripts/`, `repos/`, `README.*`, `.git*`

Everything else gets symlinked to `$HOME` when running `stow .`

## Neovim Configuration

Built on **NvChad v2.5** with **lazy.nvim** plugin manager.

```
.config/nvim/lua/
├── options.lua           # Global vim options + filetype autocommands
├── chadrc.lua            # NvChad overrides
├── plugins/init.lua      # Plugin specifications
├── configs/              # Individual plugin configs
│   ├── lspconfig.lua
│   ├── conform.lua       # Formatting
│   ├── markview.lua      # Markdown rendering
│   └── ...
└── custom/
    ├── mappings.lua      # Custom keybindings
    └── highlights.lua    # Pywal theme integration
```

**Adding filetype-specific settings**: Add autocommands to `lua/options.lua`

**Adding plugins**: Create config in `lua/configs/` and reference in `lua/plugins/init.lua`

## Shell Configuration

Load order: `.bash_profile` → `.bashrc` → `.bash_env` → `.bash_aliases` → `.bash_functions`

| File | Purpose |
|------|---------|
| `.bash_env` | Environment variables, PATH modifications |
| `.bash_aliases` | Command shortcuts (vi→nvim, k→kubectl, etc.) |
| `.bash_functions` | Shell functions (y for yazi, aws-switch-profile, etc.) |

## Platform-Specific Configs

| Config | macOS | Linux |
|--------|-------|-------|
| Terminal | Ghostty | Ghostty |
| Window Manager | AeroSpace | Hyprland |
| Scripts | `scripts/osx/Brewfile` | `scripts/ubuntu/`, `scripts/arch/` |

## Key Tools Configured

**Development**: Neovim, Git, Lazygit, fzf, ripgrep, bat, zoxide
**Containers/K8s**: Docker, kubectl, k9s, Terraform
**Cloud**: AWS CLI (with SSO functions), GitHub CLI
**Terminal**: Tmux, Tmuxinator, Starship, Yazi

## Making Changes

1. **Prefer editing existing files** over creating new ones
2. **Test changes** by sourcing configs or restarting the application
3. **Platform awareness**: Check if change is platform-specific
4. For Neovim: restart or `:Lazy reload` after plugin changes

## Common Tasks

| Task | Location |
|------|----------|
| Add shell alias | `.bash_aliases` |
| Add shell function | `.bash_functions` |
| Add env variable | `.bash_env` |
| Add vim option | `.config/nvim/lua/options.lua` |
| Add vim plugin | `.config/nvim/lua/configs/` + `plugins/init.lua` |
| Add vim keybinding | `.config/nvim/lua/custom/mappings.lua` |

## Commit Message Convention

Format: `SCOPE - Description`

- **SCOPE**: Uppercase, represents the tool/config (NVIM, BASH, TMUX, HYPR, GIT, OSX, ARCH, etc.)
- **Separator**: ` - ` (space-dash-space)
- **Description**: Sentence case, concise

Examples:
```
NVIM - Added H & J keybinds
BASH - Ignore ZSH message on new shell
OPENCODE - Added config for Grafana & Github MCPs
HYPR - Fix ouverture discord sur workspace 4
```

## AI Agent Skills

Custom skills for AI coding assistants are in `.agents/skills/`:

| Skill | Purpose |
|-------|---------|
| `commit` | Git commit with conventional commits format |
| `explorer` | Codebase exploration and teaching |
| `log` | Logging utilities |
| `find-skills` | Discover and install skills from skills.sh |
| `skill-creator` | Create new skills |
| `export-grafana-alerts` | Export Grafana alerts |

### Skill Structure

Each skill has a `SKILL.md` file with frontmatter and instructions:

```markdown
---
name: skill-name
description: What the skill does
tools: Read, Bash, Write
---

# Skill instructions here...
```

### Creating a New Skill

1. Create directory: `.agents/skills/<skill-name>/`
2. Create `SKILL.md` with frontmatter (name, description, tools)
3. Add instructions and workflows
4. Optionally add bundled resources (scripts, templates)

### Finding External Skills

Search the open skills ecosystem:
```bash
npx skills find [query]
npx skills add <owner/repo@skill>
```

Browse available skills at: https://skills.sh/
