#!/bin/bash

# Détecter automatiquement l'emplacement de ce script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Définir les dossiers de configurations sources en fonction de l'emplacement du script
REPO_ROOT_DIR="$(realpath "$SCRIPT_DIR/..")"
REPO_HOME_DIR="$(realpath "$SCRIPT_DIR/../home")"
REPO_CONFIG_DIR="$(realpath "$SCRIPT_DIR/../config")"

# Définir les dossiers de destination
SYSTEM_HOME_DIR="$HOME"
SYSTEM_CONFIG_DIR="$HOME/.config"

# Vérifier si --dry-run est utilisé
DRY_RUN=false
if [[ "$1" == "--dry-run" ]]; then
  DRY_RUN=true
  echo -e "---- Dry run activée. Aucun changement seront effectués. ----"
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
echo -e "\nTraitement du dossier $REPO_HOME_DIR vers $SYSTEM_HOME_DIR..."
for item in "$REPO_HOME_DIR"/{*,.*}; do
  # Ignorer les dossiers `.` et `..` et les motifs non résolus
  if [[ ! -e "$item" || $(basename "$item") == "." || $(basename "$item") == ".." ]]; then
    continue
  fi

  # Extraire le nom du fichier ou du dossier
  base_item=$(basename "$item")
  # Créer le symlink
  create_symlink "$item" "$SYSTEM_HOME_DIR/$base_item"
done

# Créer les symlinks pour tous les fichiers dans /config
echo -e "\nTraitement du dossier $REPO_CONFIG_DIR vers $SYSTEM_CONFIG_DIR..."
for item in "$REPO_CONFIG_DIR"/{*,.*}; do
  # Ignorer les dossiers `.` et `..`
  if [[ ! -e "$item" || $(basename "$item") == "." || $(basename "$item") == ".." ]]; then
    continue
  fi

  # Extraire le nom du fichier ou du dossier
  base_item=$(basename "$item")

  # Créer le dossier s'il n'existe pas
  if [ "$DRY_RUN" = false ]; then
    mkdir -p "$SYSTEM_CONFIG_DIR"
  fi

  # Créer le symlink
  create_symlink "$item" "$SYSTEM_CONFIG_DIR/$base_item"
done

# Créer le symlink pour le grammar highlighting des .conf logstash
HIGHLIGHT_SOURCE="$REPO_ROOT_DIR/tree-sitter-logstash/queries/highlights.scm"
HIGHLIGHT_DEST="$REPO_ROOT_DIR/nvim/queries/logstash/highlights.scm"

create_symlink "$HIGHLIGHT_SOURCE" "$HIGHLIGHT_DEST"

echo -e "\n---- Les symlinks ont été créés ! ----"
