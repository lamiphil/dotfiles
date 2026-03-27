# If not running interactively, don't do anything
case $- in
    *i*) ;;
      *) return;;
esac

# don't put duplicate lines or lines starting with space in the history.
# See bash(1) for more options
HISTCONTROL=ignoreboth

# append to the history file, don't overwrite it
shopt -s histappend

# for setting history length see HISTSIZE and HISTFILESIZE in bash(1)
HISTSIZE=1000
HISTFILESIZE=2000

# check the window size after each command and, if necessary,
# update the values of LINES and COLUMNS.
shopt -s checkwinsize

# If set, the pattern "**" used in a pathname expansion context will
# match all files and zero or more directories and subdirectories.
#shopt -s globstar

# make less more friendly for non-text input files, see lesspipe(1)
[ -x /usr/bin/lesspipe ] && eval "$(SHELL=/bin/sh lesspipe)"

# set variable identifying the chroot you work in (used in the prompt below)
if [ -z "${debian_chroot:-}" ] && [ -r /etc/debian_chroot ]; then
    debian_chroot=$(cat /etc/debian_chroot)
fi

# set a fancy prompt (non-color, unless we know we "want" color)
case "$TERM" in
    xterm-color|*-256color) color_prompt=yes;;
esac

# uncomment for a colored prompt, if the terminal has the capability; turned
# off by default to not distract the user: the focus in a terminal window
# should be on the output of commands, not on the prompt
#force_color_prompt=yes

if [ -n "$force_color_prompt" ]; then
    if [ -x /usr/bin/tput ] && tput setaf 1 >&/dev/null; then
	# We have color support; assume it's compliant with Ecma-48
	# (ISO/IEC-6429). (Lack of such support is extremely rare, and such
	# a case would tend to support setf rather than setaf.)
	color_prompt=yes
    else
	color_prompt=
    fi
fi

if [ "$color_prompt" = yes ]; then
    PS1='${debian_chroot:+($debian_chroot)}\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '
else
    PS1='${debian_chroot:+($debian_chroot)}\u@\h:\w\$ '
fi
unset color_prompt force_color_prompt

# If this is an xterm set the title to user@host:dir
case "$TERM" in
xterm*|rxvt*)
    PS1="\[\e]0;${debian_chroot:+($debian_chroot)}\u@\h: \w\a\]$PS1"
    ;;
*)
    ;;
esac

###############
# BASH FILES #
###############

if [ -f ~/.bash_env ]; then
    source ~/.bash_env
fi

if [ -f ~/.bash_aliases ]; then
    . ~/.bash_aliases
fi

# Load custom functions
if [ -f ~/.bash_functions ]; then
  source ~/.bash_functions
fi

# Load secrets from .env (gitignored)
if [ -f ~/.env ]; then
  set -a
  source ~/.env
  set +a
fi


# Run Tmux on start - Show sessions and attach to most recent
if command -v tmux &> /dev/null && [ -n "$PS1" ] && [[ ! "$TERM" =~ screen ]] && [[ ! "$TERM" =~ tmux ]] && [ -z "$TMUX" ]; then
  if tmux has-session 2>/dev/null; then
    echo "Active tmux sessions:"
    tmux list-sessions
    exec tmux attach
  else
    exec tmux new
  fi
fi

# FZF - Built-in shell integration (key-bindings + completion)
eval "$(fzf --bash)"

# Use ripgrep for fzf file searching (respects .gitignore)
export FZF_DEFAULT_COMMAND='rg --files --hidden --follow --glob "!.git/*"'
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"

# Better fzf options with preview
export FZF_DEFAULT_OPTS='
  --height 40%
  --layout=reverse
  --border
  --preview "([[ -f {} ]] && (bat --style=numbers --color=always {} || cat {})) || ([[ -d {} ]] && (tree -C {} | head -200)) || echo {} 2> /dev/null | head -200"
  --preview-window=right:50%:wrap
  --bind "ctrl-/:change-preview-window(down|hidden|)"
'

# Enhanced Ctrl+R with better history search
export FZF_CTRL_R_OPTS="
  --preview 'echo {}'
  --preview-window up:3:hidden:wrap
  --bind 'ctrl-/:toggle-preview'
  --bind 'ctrl-y:execute-silent(echo -n {2..} | pbcopy)+abort'
  --color header:italic
  --header 'Press CTRL-Y to copy command into clipboard'
"

# Load Cargo (Rust) environment if it exists
[ -f "$HOME/.cargo/env" ] && . "$HOME/.cargo/env"

###################
# AUTO-COMPLETION #
###################

# Kubectl bash completion
# source /usr/share/bash-completion/bash_completion
# source <(kubectl completion bash)
# complete -o default -F __start_kubectl k


# Bash completion
if ! shopt -oq posix; then
  if [ -f /usr/share/bash-completion/bash_completion ]; then
    . /usr/share/bash-completion/bash_completion
  elif [ -f /etc/bash_completion ]; then
    . /etc/bash_completion
  fi
fi

# make tab cycle through commands after listing
bind '"\t":menu-complete'
bind "set show-all-if-ambiguous on"
bind "set completion-ignore-case on"
bind "set menu-complete-display-prefix on"

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion

########
# PATH #
########

# Go Environment
export GOPATH="/usr/local/go/go"
export PATH="$PATH:$GOPATH/bin:/usr/local/go/bin"

# Additional Paths
export PATH="$HOME/.local/bin:/opt/nvim-linux64/bin:$PATH"

######## 
# INIT # 
######## 

# Starship
eval "$(starship init bash)"

# zoxide
eval "$(zoxide init --cmd cd bash)"

# Start ssh-agent
eval $(ssh-agent -s) > /dev/null

# Load SSH key
ssh-add ~/.ssh/github > /dev/null 2>&1

# Apply pywal color theme (if installed), except in Ghostty or tmux sessions
if [ "${TERM_PROGRAM:-}" != "ghostty" ] && [ -z "${TMUX:-}" ]; then
  if [ -f ~/.cache/wal/sequences ]; then
    (cat ~/.cache/wal/sequences &)
    # Alternative (blocks terminal for 0-3ms)
    cat ~/.cache/wal/sequences
  fi

  # To add support for TTYs this line can be optionally added.
  [ -f ~/.cache/wal/colors-tty.sh ] && source ~/.cache/wal/colors-tty.sh
fi

# If Bash is running is not interactive mode, return here. 
# Everything following will only be applied to interactive sessions
[ -z "$PS1" ] && return
export PATH="$HOME/.tfenv/bin:$PATH"
export PATH="$HOME/.tfenv/bin:$PATH"

# opencode
export PATH=/Users/philippe.lamy/.opencode/bin:$PATH


# nvm
export NVM_DIR="$HOME/.nvm"
  [ -s "/opt/homebrew/opt/nvm/nvm.sh" ] && \. "/opt/homebrew/opt/nvm/nvm.sh"
