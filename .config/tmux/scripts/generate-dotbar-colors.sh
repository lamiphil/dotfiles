#!/bin/bash

# Charger les couleurs
source "$HOME/.cache/wal/colors.sh"

# Générer un fichier tmux utilisable
cat <<EOF > "$HOME/.config/tmux/dotbar-colors.conf"
# Généré automatiquement par wal
set -g @tmux-dotbar-fg "$foreground"
set -g @tmux-dotbar-bg "$background"
set -g @tmux-dotbar-fg-current "$color6"
set -g @tmux-dotbar-fg-session "$color7"
set -g @tmux-dotbar-fg-prefix "$color6"
EOF

