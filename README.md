# dotfiles

Personal dotfiles for macOS, Ubuntu/Debian, and Arch Linux — managed with [GNU Stow](https://www.gnu.org/software/stow/).

## What's Included

| Category | Tools |
|----------|-------|
| **Shell** | Bash, [Starship](https://starship.rs) prompt, [Zoxide](https://github.com/ajeetdsouza/zoxide) |
| **Editor** | [Neovim](https://neovim.io) (NvChad + lazy.nvim) |
| **Terminal** | [Ghostty](https://ghostty.org), [Tmux](https://github.com/tmux/tmux) + TPM |
| **File Manager** | [Yazi](https://yazi-rs.github.io) |
| **Git** | [Lazygit](https://github.com/jesseduffield/lazygit), Git aliases |
| **Search** | [fzf](https://github.com/junegunn/fzf), [ripgrep](https://github.com/BurntSushi/ripgrep), [bat](https://github.com/sharkdp/bat) |
| **Containers/K8s** | Docker, kubectl, [k9s](https://k9scli.io) |
| **Cloud** | AWS CLI (with SSO helpers), GitHub CLI, Terraform |
| **Window Manager** | [AeroSpace](https://github.com/nikitabobko/AeroSpace) (macOS), [Hyprland](https://hyprland.org) (Linux) |
| **Theming** | [Pywal](https://github.com/dylanaraps/pywal), [lsd](https://github.com/lsd-rs/lsd) |
| **Monitoring** | [btop](https://github.com/aristocratos/btop) |
| **AI Tools** | [OpenCode](https://opencode.ai), custom agent skills |

## Repository Structure

```
dotfiles/
├── .bash_profile             # Login shell entrypoint
├── .bashrc                   # Interactive shell config
├── .bash_env                 # Environment variables, PATH
├── .bash_aliases             # Command shortcuts
├── .bash_functions           # Shell functions
├── .gitconfig                # Git user & aliases
├── starship.toml             # Starship prompt config
├── .config/
│   ├── nvim/                 # Neovim (NvChad v2.5 + lazy.nvim)
│   ├── tmux/                 # Tmux with TPM plugins
│   ├── ghostty/              # Ghostty terminal
│   ├── aerospace/            # AeroSpace WM (macOS)
│   ├── hypr/                 # Hyprland WM (Linux)
│   ├── yazi/                 # Yazi file manager
│   ├── k9s/                  # Kubernetes TUI
│   ├── lazygit/              # Lazygit TUI
│   ├── rofi/                 # Rofi launcher (Linux)
│   ├── waybar/               # Waybar status bar (Linux)
│   ├── btop/                 # System monitor
│   ├── opencode/             # OpenCode AI tool + MCP servers
│   ├── obsidian/             # Obsidian vault config
│   └── ...
├── .agents/skills/           # AI agent skills
├── scripts/                  # Platform-specific install scripts
└── wallpapers/               # Desktop wallpapers
```

## Setup

### 0. Prerequisites

- [ ] **Git** must be installed
- [ ] **Bash** is the expected shell

### 1. SSH Configuration

- [ ] 1.1 Generate an SSH key ([GitHub docs](https://docs.github.com/en/authentication/connecting-to-github-with-ssh/generating-a-new-ssh-key-and-adding-it-to-the-ssh-agent)):
```bash
ssh-keygen -t ed25519 -C "your-email@example.com"
```

- [ ] 1.2 When prompted, save the key as `~/.ssh/github`

- [ ] 1.3 Add the public key to GitHub → [Settings > SSH Keys](https://github.com/settings/keys)

- [ ] 1.4 Create the SSH config:
```bash
cat >> ~/.ssh/config << 'EOF'
Host github
    Hostname github.com
    IdentityFile ~/.ssh/github
    IdentitiesOnly yes
    AddKeysToAgent yes
EOF
```

### 2. Clone the Repository

```bash
cd ~
git clone git@github.com:lamiphil/dotfiles.git
```

### 3. Install Packages

#### macOS

- [ ] 3.1 Install [Homebrew](https://brew.sh) if not already installed:
```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

- [ ] 3.2 Install packages from the Brewfile:
```bash
brew bundle --file=~/dotfiles/scripts/osx/Brewfile
```

This installs: git, neovim, tree, python, lsd, bat, tmux, tmuxinator, fzf, stow, ripgrep, starship, rust, yazi, lazygit, chafa, yarn, btop, and Ghostty.

#### Ubuntu / Debian

- [ ] 3.1 Run the install script:
```bash
sudo ~/dotfiles/scripts/ubuntu/install_packages.sh
```

- [ ] 3.2 Install [Starship](https://starship.rs):
```bash
curl -sS https://starship.rs/install.sh | sh
```

- [ ] 3.3 Install [Neovim](https://github.com/neovim/neovim/releases/) (latest stable):
```bash
wget https://github.com/neovim/neovim/releases/download/stable/nvim-linux64.tar.gz
tar xzvf nvim-linux64.tar.gz
sudo mv nvim-linux64 /opt/nvim
sudo ln -s /opt/nvim/bin/nvim /usr/local/bin/nvim
```

#### Arch Linux

- [ ] 3.1 Run the install script:
```bash
sudo ~/dotfiles/scripts/arch/install_packages.sh
```

This handles pacman packages, AUR packages (via yay), Starship, Yazi, and TPM.

### 4. Install Nerd Font

- [ ] 4.1 Run the font install script (all platforms):
```bash
~/dotfiles/scripts/init/install_nerdfont.sh
```

This installs [JetBrains Mono Nerd Font](https://www.nerdfonts.com).

### 5. Apply Dotfiles with Stow

- [ ] 5.1 Back up any existing dotfiles that would conflict (e.g. `~/.bashrc`, `~/.bash_profile`)

- [ ] 5.2 Run Stow from the repo root:
```bash
cd ~/dotfiles
stow .
```

This symlinks everything to `$HOME`, except files listed in `.stow-local-ignore` (scripts, README, git metadata, etc.).

### 6. Tmux Plugin Manager

- [ ] 6.1 Install [TPM](https://github.com/tmux-plugins/tpm):
```bash
git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
```

- [ ] 6.2 Open Tmux, then press `Ctrl+Space` followed by `I` (capital) to install plugins.

### 7. Neovim Plugins

- [ ] 7.1 Open Neovim — lazy.nvim will automatically bootstrap and install all plugins:
```bash
nvim
```

- [ ] 7.2 Run `:Lazy install` if plugins didn't install automatically.

### 8. Terminal Configuration

Ghostty is the default terminal on all platforms. After stowing, the config is already symlinked. Just set:

- **Font**: BerkeleyMono Nerd Font Mono (or JetBrains Mono Nerd Font as fallback)
- **Theme**: OneDark-Pro (configured in `~/.config/ghostty/config`)

### 9. Create Workspaces

Workspaces are project-specific directories under `~/workspaces/`. Each workspace contains repos, an Obsidian vault for notes, and shared Obsidian configuration symlinked from this dotfiles repo.

There are two types of workspaces:

| Type | Description |
|------|-------------|
| **work** | For a job or organization. Empty notes folder (not a repo), `issues/` and `tools/` directories. |
| **personal** | For personal projects. Clones the [notes](https://github.com/lamiphil/notes) and [portfolio](https://github.com/lamiphil/portfolio) repos from GitHub. |

Both types generate a `CLAUDE.md` template tailored to the workspace type.

#### Workspace structure

```
~/workspaces/<name>/
├── CLAUDE.md           # AI assistant context (generated template)
├── repos/              # Git repositories
├── notes/              # Obsidian vault
│   ├── .obsidian/  ->  ~/dotfiles/.config/obsidian/.obsidian
│   └── _config/    ->  ~/dotfiles/.config/obsidian/_config
├── issues/             # (work only) Working directories for tasks
└── tools/              # (work only) API collections and tooling
```

- [ ] 9.1 Run the workspace init script:
```bash
~/dotfiles/scripts/init/init_workspace.sh
```

The script will prompt for a workspace name and type, then create the full structure. It is idempotent — safe to re-run on existing workspaces without breaking anything.

## Shell Overview

Load order: `.bash_profile` → `.bashrc` → `.bash_env` → `.bash_aliases` → `.bash_functions` → `.env`

| File | Purpose |
|------|---------|
| `.bash_env` | Environment variables, PATH, `DOTFILES_ENV` toggle (`perso` / `work`) |
| `.bash_aliases` | Shortcuts: `vi` → nvim, `k` → kubectl, `lg` → lazygit, `ls` → lsd, etc. |
| `.bash_functions` | `cd()` auto-ls, `y()` yazi wrapper, `aws-switch-profile()`, `aws-sso-login()` |

The shell auto-starts Tmux on launch, initializes Starship, Zoxide, ssh-agent, and Pywal colors.

## Key Bindings

### Tmux (prefix: `Ctrl+Space`)

| Binding | Action |
|---------|--------|
| `h` / `v` | Horizontal / vertical split |
| `c` | New window |
| `Shift+Alt+H/L` | Previous / next window |
| `Ctrl+h/j/k/l` | Navigate panes (vim-style, shared with Neovim) |
| `Ctrl+Alt+h/j/k/l` | Resize panes |
| `Alt+s` | Toggle synchronized panes |
| `r` | Reload config |

### AeroSpace — macOS (modifier: `Alt`)

| Binding | Action |
|---------|--------|
| `Alt+h/j/k/l` | Focus window |
| `Alt+Shift+h/j/k/l` | Move window |
| `Alt+1-5` | Switch workspace |
| `Alt+Shift+1-5` | Move window to workspace |
| `Alt+-/=` | Resize |

### Hyprland — Linux (modifier: `Super`)

See `.config/hypr/hyprland.conf` for the full binding list.

## AI Agent Skills

Custom skills for AI coding assistants live in `.agents/skills/`:

| Skill | Purpose |
|-------|---------|
| `commit` | Git commit with conventional format |
| `explorer` | Codebase exploration and teaching |
| `log` | Progress logging |
| `pull` | Git pull across repos |
| `find-skills` | Discover skills from [skills.sh](https://skills.sh) |
| `skill-creator` | Create new skills |
| `logging-best-practices` | Wide events logging patterns |
| `export-grafana-alerts` | Export Grafana alert rules |

Install external skills:
```bash
npx skills find [query]
npx skills add <owner/repo@skill>
```

## Platform Differences

| Component | macOS | Linux |
|-----------|-------|-------|
| Terminal | Ghostty | Ghostty |
| Window Manager | AeroSpace | Hyprland |
| Status Bar | — | Waybar |
| App Launcher | Raycast | Rofi |
| Logout Menu | — | wlogout |
| Package Manager | Homebrew | apt / pacman + yay |
