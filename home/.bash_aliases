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
alias dot="cd ~/code/perso/dotfiles/ && nvim"
alias elk="cd ~/code/elk/ && nvim"
alias home="cd ~"

# bash
alias rc="nvim ~/code/perso/dotfiles/home/.bashrc"
alias aliases="nvim ~/code/perso/dotfiles/home/.bash_aliases"

# kubectl
alias k="kubectl"

# minikube
alias mini="minikube"

# tmuxinator
alias mux="tmuxinator"
