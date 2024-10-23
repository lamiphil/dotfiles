#!/bin/bash

# Définit les dossiers de configurations sources
REPO_HOME_DIR="/home/code/perso/dotfiles/home"
REPO_CONFIG_DIR="/home/code/perso/dotfiles/config"

# Définir les dossiers de destination
SYSTEM_HOME_DIR="/home"
SYSTEM_CONFIG_DIR="/home/config"

# Vérifier si --dry-run est utilisé
DRY_RUN=false
if [[ "$1" == "--dry-run" ]]; then
  DRY_RUN=true
  echo "---- Dry run activée. Aucun changement seront effectués. ----"
fi

# Fonction qui permet de créer les symlinks
create_symlink() {
  local source=$1
  local destination=$2

  if [ "$DRY_RUN" = true ]; then
    echo -e "\tAurait créé... ln -sf \"$source\" \"$destination\""
  else
    ln -sf "$source" "$destination"
    echo -e "\tSymlink créé : ln -sf \"$source\" \"$destination\""
  fi
}

# Créer les symlinks pour tous les fichiers dans /home
echo "Traitement du dossier $REPO_HOME_DIR vers $SYSTEM_HOME_DIR..."
for item in "$REPO_HOME_DIR"/*; do
  # Extraire le nom du fichier ou du dossier
  base_item=$(basename "$item")

  # Créer le symlink
  create_symlink "$item" "$SYSTEM_HOME_DIR/$base_item"
done

# Créer les symlinks pour tous les fichiers dans /config
echo "Traitement du dossier $REPO_CONFIG_DIR vers $SYSTEM_CONFIG_DIR..."
for item in "$REPO_CONFIG_DIR"/*; do
  # Extraire le nom du fichier ou du dossier
  base_item=$(basename "$item")

  # Créer le dossier s'il n'existe pas
  if [ "$DRY_RUN" = false ]; then
    mkdir -p "$SYSTEM_CONFIG_DIR"
  fi

  # Créer le symlink
  create_symlink "$item" "$SYSTEM_CONFIG_DIR/$base_item"
done

echo "Les symlinks ont été créés !"
