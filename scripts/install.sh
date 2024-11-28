#!/bin/bash

# Vérifier si le script est exécuté entant que root ou avec sudo
if ["$EUID" -ne 0]; then
  echo "ERREUR - Exécuter ce script entant que root ou avec sudo."
  exit 1
fi

# Liste des packages à installer
PACKAGES=(
  "git"
  "neovim"
  "tree"
  "python3-pip"
  "python3-venv"
  "unzip"
  "lsd"
  "bat"
  "tmux"
  "tmuxinator"
)

echo "Mise à jour de la liste des packages..."
apt update -y

echo "Installation des packages..."
for package in "${PACKAGES[@]}"; do 
  apt install "$package" -y 
done

echo "Ménage..."
apt autoremove -y
apt clean

echo "Les packages ont été installés avec succès !"
