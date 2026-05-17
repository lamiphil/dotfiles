####################
# NAVIGATION       #
####################

alias cd1="cd .."
alias cd2="cd ../.."
alias cd3="cd ../../.."
alias cd4="cd ../../../.."

####################
# LS (lsd)         #
####################

alias ls="lsd"
alias ll="lsd -ahl"
alias la="lsd -A"
alias l="lsd -CF"

####################
# EDITOR           #
####################

alias vi="nvim"
alias vim="nvim"
alias v="nvim"

####################
# DOCKER           #
####################

alias dcu="docker compose up"
alias dcd="docker compose down"
alias dcb="docker compose build"
alias dcud="docker compose up -d"

####################
# BAT              #
####################

if command -q batcat
    alias bat="batcat"
end

####################
# SHORTCUTS        #
####################

alias home="cd ~"

# Config editing (updated for fish)
alias rc="nvim ~/.config/fish/config.fish"
alias aliases="nvim ~/.config/fish/conf.d/aliases.fish"

####################
# KUBECTL          #
####################

alias k="kubectl"

####################
# MINIKUBE         #
####################

alias mini="minikube"

####################
# SYSTEMCTL        #
####################

alias sys="systemctl"

####################
# TERRAFORM        #
####################

alias tf="terraform"

####################
# LAZYGIT          #
####################

alias lg="lazygit"

####################
# PYTHON           #
####################

alias p="python3"

####################
# OPENCODE         #
####################

alias oc="ocv --port"
