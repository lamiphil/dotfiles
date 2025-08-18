#!/bin/bash

# Vérifie que le script est lancé avec sudo
if [ "$EUID" -ne 0 ]; then
  echo "ERREUR : ce script doit être lancé avec sudo."
  exit 1
fi

# Liste des paquets à installer avec pacman
PACMAN_PKGS=(
  git
  neovim
  tree
  python
  python-pip
  unzip
  lsd
  bat
  tmux
  fzf
  stow
  ripgrep
  wget
  bash-completion
  pavucontrol
  hyprlock
  waybar
  hyprpaper
  hypridle
  greetd
  tuigreet
  wl-clipboard
  lazygit
  rofi-wayland
)

# Listes des paquets à installer avec l'AUR
YAY_PKGS=(
  tmuxinator
  wlogout
  swaync
  hyprshot
)

# Installer les paquets de base
echo "🔧 Mise à jour du système..."
pacman -Syu --noconfirm

# Installer yay s'il n'existe pas déjà
if ! command -v yay &>/dev/null; then
  echo "📦 Installation de yay (AUR helper)..."
  cd /opt && git clone https://aur.archlinux.org/yay.git
  chown -R "$SUDO_USER":"$SUDO_USER" yay
  cd yay && sudo -u "$SUDO_USER" makepkg -si --noconfirm
fi

# Installer les paquets principaux
echo "📦 Installation des paquets principaux..."
for pkg in "${PACMAN_PKGS[@]}"; do
  pacman -S --needed --noconfirm "$pkg"
done

# Installer les paquets secondaires via l'AUR
echo "📦 Installation des paquets secondaires..."
for pkg in "${YAY_PKGS[@]}"; do
  yay -S --noconfirm "$pkg"
done

# Installation de paquets supplementaires
echo "Installation de yazi..."
pacman -S --noconfirm yazi ffmpeg 7zip jq poppler fd ripgrep fzf zoxide imagemagick

# Installer Starship
echo "🚀 Installation de Starship..."
sudo -u "$SUDO_USER" sh -c "$(curl -fsSL https://starship.rs/install.sh)" -- --yes

# Installer Tmux Plugin Manager (TPM)
echo "🔌 Installation de Tmux Plugin Manager..."
sudo -u "$SUDO_USER" git clone https://github.com/tmux-plugins/tpm /home/$SUDO_USER/.tmux/plugins/tpm

echo "✅ Installation terminée. N'oublie pas :"
echo "1. Lance Neovim et exécute :LazyInstall"
echo "2. Lance tmux et fais CTRL+SPACE puis I (majuscule)"
echo "3. Clone tes dotfiles et exécute : stow ."
