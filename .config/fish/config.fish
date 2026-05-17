###############
# ENVIRONMENT #
###############

set -gx XDG_CONFIG_HOME "$HOME/.config"
set -gx EDITOR nvim
set -gx LANG en_US.UTF-8
set -gx LC_ALL en_US.UTF-8

# Linux-specific
set -gx HYPRSHOT_DIR "$HOME/Pictures/"
set -gx GTK_THEME "Adwaita:dark"

########
# PATH #
########

# Homebrew (macOS)
if test -x /opt/homebrew/bin/brew
    eval (/opt/homebrew/bin/brew shellenv)
end

# Local bin + nvim (Linux)
fish_add_path "$HOME/.local/bin"
fish_add_path /opt/nvim-linux64/bin

# Go
set -gx GOPATH /usr/local/go/go
fish_add_path "$GOPATH/bin" /usr/local/go/bin

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

# Apply pywal colors outside Ghostty and tmux
if test "$TERM_PROGRAM" != ghostty; and not set -q TMUX
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
starship init fish | source

# Zoxide with cd override (--cmd cd sets alias cd=__zoxide_z)
zoxide init --cmd cd fish | source

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

# FZF key bindings and completions (must come after vi bindings to keep Ctrl+R)
fzf --fish | source
