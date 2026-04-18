# dotfiles

Personal dotfiles for Arch Linux and macOS — managed with [GNU Stow](https://www.gnu.org/software/stow/).

## What's Included

| Category | Tools |
|----------|-------|
| **Shell** | Bash, [Starship](https://starship.rs), [Zoxide](https://github.com/ajeetdsouza/zoxide) |
| **Editor** | [Neovim](https://neovim.io) (Kickstart.nvim + lazy.nvim) |
| **Terminal** | [Ghostty](https://ghostty.org), [Tmux](https://github.com/tmux/tmux) + TPM |
| **File Manager** | [Yazi](https://yazi-rs.github.io) |
| **Git** | [Lazygit](https://github.com/jesseduffield/lazygit), Git aliases |
| **Search** | [fzf](https://github.com/junegunn/fzf), [ripgrep](https://github.com/BurntSushi/ripgrep), [bat](https://github.com/sharkdop/bat), [Television](https://github.com/alexpasmantier/television) |
| **Containers/K8s** | Docker, kubectl, [k9s](https://k9scli.io) |
| **Cloud** | AWS CLI (with SSO helpers), GitHub CLI, Terraform |
| **Window Manager** | [AeroSpace](https://github.com/nikitabobko/AeroSpace) (macOS), [Hyprland](https://hyprland.org) (Linux) |
| **Theming** | [Pywal](https://github.com/dylanaraps/pywal), [lsd](https://github.com/lsd-rs/lsd) |
| **AI** | [OpenCode](https://opencode.ai) |

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
├── .config/                  # Custom config files
├── .agents/skills/           # AI agent skills
├── scripts/                  # Platform-specific install scripts
└── wallpapers/               # Desktop wallpapers
```

## Setup

### 1. SSH Configuration

Generate an SSH key and add it to GitHub ([docs](https://docs.github.com/en/authentication/connecting-to-github-with-ssh/generating-a-new-ssh-key-and-adding-it-to-the-ssh-agent)):

```bash
ssh-keygen -t ed25519 -C "your-email@example.com"
```

Save the key as `~/.ssh/github`, then add the public key to [GitHub SSH Keys](https://github.com/settings/keys).

Create the SSH config:

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

#### Arch Linux

```bash
sudo ~/dotfiles/scripts/arch/install_packages.sh
```

This handles pacman packages, AUR packages (via yay), Starship, Yazi, and TPM.

#### macOS

Install [Homebrew](https://brew.sh) if needed, then:

```bash
brew bundle --file=~/dotfiles/scripts/osx/Brewfile
```

### 4. Install Nerd Font

```bash
~/dotfiles/scripts/init/install_nerdfont.sh
```

### 5. Apply Dotfiles with Stow

Back up any existing dotfiles that would conflict (e.g. `~/.bashrc`, `~/.bash_profile`), then:

```bash
cd ~/dotfiles
stow .
```

This symlinks everything to `$HOME`, except files listed in `.stow-local-ignore` (scripts, README, git metadata, etc.).

### 6. Tmux Plugins

Install [TPM](https://github.com/tmux-plugins/tpm):

```bash
git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
```

Open Tmux, then press `Ctrl+Space` followed by `I` (capital) to install plugins.

### 7. Neovim Plugins

Open Neovim — lazy.nvim will automatically bootstrap and install all plugins:

```bash
nvim
```

### 8. Create Workspaces

Workspaces are project directories under `~/workspaces/`. Each workspace contains repos, an Obsidian vault for notes, and shared Obsidian configuration symlinked from this dotfiles repo.

| Type | Description |
|------|-------------|
| **work** | For a job or organization. Empty notes folder, `issues/` and `tools/` directories. |
| **personal** | For personal projects. Clones the [notes](https://github.com/lamiphil/notes) and [portfolio](https://github.com/lamiphil/portfolio) repos. |

#### Workspace structure

```
~/workspaces/<name>/
├── AGENTS.md           # AI assistant context (generated template)
├── repos/              # Git repositories
├── notes/              # Obsidian vault
│   ├── .obsidian/  ->  ~/dotfiles/.config/obsidian/.obsidian
│   └── _config/    ->  ~/dotfiles/.config/obsidian/_config
├── issues/             # (work only)
└── tools/              # (work only)
```

Run the workspace init script:

```bash
~/dotfiles/scripts/init/init_workspace.sh
```
