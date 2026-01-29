if [ -f ~/.bashrc ]; then
  source ~/.bashrc
fi

# Load Cargo (Rust) environment if it exists
[ -f "$HOME/.cargo/env" ] && . "$HOME/.cargo/env"

# Load flux completion if flux is installed
command -v flux &> /dev/null && . <(flux completion bash)
