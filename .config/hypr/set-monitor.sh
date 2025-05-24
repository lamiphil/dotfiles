#!/bin/bash

# Script pour basculer entre écran externe et écran laptop automatiquement

if hyprctl monitors | grep -q "HDMI-A-1"; then
  # Si l'écran externe est branché
  echo "✅ Écran HDMI détecté. Activation de HDMI-A-1 uniquement."
  hyprctl keyword monitor "HDMI-A-1,3440x1440@85,0x0,1"
  hyprctl keyword monitor "eDP-1,disable"
else
  # Sinon, utiliser uniquement l'écran du laptop
  echo "ℹ️ Aucun écran HDMI détecté. Activation de eDP-1."
  hyprctl keyword monitor "eDP-1,1920x1200@60,0x0,1"
fi
