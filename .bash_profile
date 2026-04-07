# Silence macOS bash deprecation warning
export BASH_SILENCE_DEPRECATION_WARNING=1

if [ -f ~/.bashrc ]; then
  source ~/.bashrc
fi

# Load Cargo (Rust) environment if it exists
[ -f "$HOME/.cargo/env" ] && . "$HOME/.cargo/env"

# Load flux completion if flux is installed
command -v flux &> /dev/null && . <(flux completion bash)

# Homebrew
if [[ -x /opt/homebrew/bin/brew ]]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
fi
# Bash completion
if [[ -r /opt/homebrew/etc/profile.d/bash_completion.sh ]]; then
  . /opt/homebrew/etc/profile.d/bash_completion.sh
fi

# bun
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"

