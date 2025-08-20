###################
# DEFAULT ALIASES #
###################

# enable color support of ls and also add handy aliases
if [ -x /usr/bin/dircolors ]; then
    test -r ~/.dircolors && eval "$(dircolors -b ~/.dircolors)" || eval "$(dircolors -b)"
    alias ls='ls --color=auto'
    #alias dir='dir --color=auto'
    #alias vdir='vdir --color=auto'

    alias grep='grep --color=auto'
    alias fgrep='fgrep --color=auto'
    alias egrep='egrep --color=auto'
fi

# some more ls aliases
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'

# Add an "alert" alias for long running commands.  Use like so:
#   sleep 10; alert
alias alert='notify-send --urgency=low -i "$([ $? = 0 ] && echo terminal || echo error)" "$(history|tail -n1|sed -e '\''s/^\s*[0-9]\+\s*//;s/[;&|]\s*alert$//'\'')"'

##################
# CUSTOM ALIASES #
##################

# cd
alias cd1="cd .."
alias cd2="cd ../../"
alias cd3="cd ../../../"
alias cd4="cd ../../../../"

# ls
alias ls="lsd"
alias ll="lsd -ahl"

# vim
alias vi="nvim"
alias vim="nvim"
alias v="nvim"

# docker
alias dcu="docker compose up"
alias dcd="docker compose down"
alias dcb="docker compose build"
alias dcud="docker compose up -d"
alias dcrd="docker compose down & docker compose up -d" # Restart in deamon
alias dcr="docker compose down & docker compose up" # Restart filebeat
alias dcrf="docker compose down filebeat ; docker compose up filebeat -d" # Restart filebeat

# bat
alias bat="batcat"

# shorcuts
alias dot="cd ~/dotfiles/ && nvim"
alias home="cd ~"
alias lq="cd ~/code/"
alias obs="cd ~/code/obs/"

if [[ $DOTFILES_ENV == "perso" ]]; then
  alias notes="cd ~/notes/perso/ && nvim +ObsidianToday"
else
  alias notes="cd ~/notes/ && nvim +ObsidianToday"
fi

# bash
alias rc="nvim ~/.bashrc"
alias aliases="nvim ~/.bash_aliases"

# kubectl
alias k="kubectl"
alias kpo="kubectl config use-context admin@k8s-REDACTED"
alias kti="kubectl config use-context admin@k8s-REDACTED"

# minikube
alias mini="minikube"

# tmuxinator
alias mux="tmuxinator"

# fzf
alias fzf="fzf --preview 'batcat --style=numbers --color=always {}'"

# systemctl
alias sys="systemctl"

# terraform
alias tf="terraform"

# lazygit
alias lg="lazygit"

# python3
alias p="python3"
