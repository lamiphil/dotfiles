#!/bin/bash

# Generate tmux dotbar colors from the Ghostty OneDark palette.
cat <<EOF > "$HOME/.config/tmux/dotbar-colors.conf"
# Ghostty OneDark palette
set -g @tmux-dotbar-fg "#ABB2BF"
set -g @tmux-dotbar-bg "#3F4451"
set -g @tmux-dotbar-fg-current "#61AFEF"
set -g @tmux-dotbar-fg-session "#ABB2BF"
set -g @tmux-dotbar-fg-prefix "#56B6C2"
EOF
