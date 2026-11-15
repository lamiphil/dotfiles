###############
# ENVIRONMENT #
###############

set -gx XDG_CONFIG_HOME "$HOME/.config"
set -gx NPM_CONFIG_USERCONFIG "$XDG_CONFIG_HOME/npm/npmrc"
set -gx PI_TIDY_SUBAGENT_EXECUTABLE pi
set -gx EDITOR nvim
set -gx LANG en_US.UTF-8
set -gx LC_ALL en_US.UTF-8
set -g fish_greeting

# Linux-specific desktop integrations.
if test (uname) = Linux
    set -gx HYPRSHOT_DIR "$HOME/Pictures/"
    set -gx ADW_DISABLE_PORTAL 1
end

########
# PATH #
########

# Homebrew (GUI apps do not inherit the login shell PATH on macOS)
if test -x /opt/homebrew/bin/brew
    eval (/opt/homebrew/bin/brew shellenv)
else if command -q brew
    eval (brew shellenv)
end

# User-installed tools work on both macOS and Linux.
fish_add_path "$HOME/.local/bin"

# Linux-only Neovim tarball installation.
if test (uname) = Linux; and test -d /opt/nvim-linux64/bin
    fish_add_path /opt/nvim-linux64/bin
end

# Go: keep the workspace in the home directory; Go itself may be installed by
# Homebrew on macOS or under /usr/local/go on Linux.
set -gx GOPATH "$HOME/go"
fish_add_path "$GOPATH/bin"
if test -d /usr/local/go/bin
    fish_add_path /usr/local/go/bin
end

# tfenv
fish_add_path "$HOME/.tfenv/bin"

# OpenCode
fish_add_path "$HOME/.opencode/bin"

# Bun
set -gx BUN_INSTALL "$HOME/.bun"
fish_add_path "$BUN_INSTALL/bin"

# Cargo (Rust)
fish_add_path "$HOME/.cargo/bin"

###########
# SECRETS #
###########

# Load secrets and machine-specific overrides (gitignored)
source_env ~/.env
source_env ~/.env.local

##########
# PYWAL  #
##########

# Apply pywal colors outside Ghostty, Rex, and tmux
if test "$TERM_PROGRAM" != ghostty; and not set -q REX_SESSION; and not set -q TMUX
    if test -f ~/.cache/wal/sequences
        cat ~/.cache/wal/sequences
    end
    if test -f ~/.cache/wal/colors-tty.sh
        source ~/.cache/wal/colors-tty.sh
    end
end

###############
# SSH AGENT   #
###############

if not set -q SSH_AUTH_SOCK
    eval (ssh-agent -c) > /dev/null
end
ssh-add ~/.ssh/github 2>/dev/null

#######
# FZF #
#######

set -gx FZF_DEFAULT_COMMAND 'rg --files --hidden --follow --glob "!.git/*"'
set -gx FZF_CTRL_T_COMMAND "$FZF_DEFAULT_COMMAND"
set -gx FZF_DEFAULT_OPTS '--height 40% --layout=reverse --border --preview "([[ -f {} ]] && (bat --style=numbers --color=always {} || cat {})) || ([[ -d {} ]] && (tree -C {} | head -200)) || echo {} 2> /dev/null | head -200" --preview-window=right:50%:wrap --bind "ctrl-/:change-preview-window(down|hidden|)"'

########
# INIT #
########

# Starship prompt
if type -q starship
    starship init fish | source
end

# Zoxide with cd override (--cmd cd sets alias cd=__zoxide_z)
if type -q zoxide
    zoxide init --cmd cd fish | source
end

# Re-define cd on top of zoxide to add auto-ls
function cd --wraps=__zoxide_z --description "zoxide cd with auto-ls"
    __zoxide_z $argv
    and ll
end

# Vi key bindings (normal/insert/visual modes)
set -g fish_key_bindings fish_vi_key_bindings

# Restore Ctrl+L to clear screen (fish_vi_key_bindings removes it)
bind -M insert \cl 'clear; commandline -f repaint'
bind -M default \cl 'clear; commandline -f repaint'

# Ctrl+Shift+L also clears (Rex uses Ctrl+L for pane navigation).
bind -M insert ctrl-shift-l 'clear; commandline -f repaint'
bind -M default ctrl-shift-l 'clear; commandline -f repaint'

# FZF key bindings and completions (must come after vi bindings to keep Ctrl+R)
if type -q fzf
    fzf --fish | source
end

# bun
set --export BUN_INSTALL "$HOME/.bun"
set --export PATH $BUN_INSTALL/bin $PATH

###########
# ALIASES #
###########

alias claude 'claude --dangerously-skip-permissions'
