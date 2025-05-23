#!/bin/bash

# --- Configuration ---
FONT_NAME="JetBrainsMono"
FONT_VERSION="v3.4.0"
DOWNLOAD_URL="https://github.com/ryanoasis/nerd-fonts/releases/download/${FONT_VERSION}/${FONT_NAME}.zip"
FONT_DIR="$HOME/.local/share/fonts"
TMP_DIR="$HOME/Downloads/"

# --- Téléchargement ---
echo "⬇️ Téléchargement de ${FONT_NAME} depuis Nerd Fonts..."
curl -L "$DOWNLOAD_URL" -o "$TMP_DIR/${FONT_NAME}.zip"

# --- Décompression ---
echo "📦 Décompression..."
unzip -q "$TMP_DIR/${FONT_NAME}.zip" -d "$TMP_DIR"

# --- Installation dans ~/.local/share/fonts ---
echo "🚚 Copie des polices dans $FONT_DIR"
mkdir -p "$FONT_DIR"
find "$TMP_DIR" -name "*.ttf" -exec cp {} "$FONT_DIR" \;

# --- Rechargement de la cache de police ---
echo "🔄 Rechargement de la cache des polices..."
fc-cache -fv > /dev/null

echo "✅ Installation terminée : ${FONT_NAME} Nerd Font est maintenant disponible !"

