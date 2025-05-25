#!/bin/bash

# Vérifier si le script est exécuté entant que root ou avec sudo
if ["$EUID" -ne 0]; then
  echo "ERREUR - Exécuter ce script entant que root ou avec sudo."
  exit 1
fi

