#!/usr/bin/env bash

set -euo pipefail

THEME="$HOME/.config/waybar/power-menu.rasi"

run_rofi() {
  rofi -dmenu \
    -i \
    -no-custom \
    -p "Power" \
    -theme "$THEME"
}

confirm_rofi() {
  rofi -dmenu \
    -i \
    -no-custom \
    -p "Confirm" \
    -theme "$THEME" \
    -theme-str 'window { width: 240px; } listview { lines: 2; }'
}

logout() {
  if [[ "${DESKTOP_SESSION:-}" == 'hyprland' || -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]]; then
    hyprctl dispatch exit
  elif [[ "${DESKTOP_SESSION:-}" == 'openbox' ]]; then
    openbox --exit
  elif [[ "${DESKTOP_SESSION:-}" == 'bspwm' ]]; then
    bspc quit
  elif [[ "${DESKTOP_SESSION:-}" == 'i3' ]]; then
    i3-msg exit
  elif [[ "${DESKTOP_SESSION:-}" == 'plasma' ]]; then
    qdbus org.kde.ksmserver /KSMServer logout 0 0 0
  else
    loginctl terminate-user "${USER}"
  fi
}

confirm_and_run() {
  local label="$1"
  local command="$2"
  local answer
  answer=$(printf 'No\nYes' | confirm_rofi)

  [[ "$answer" == 'Yes' ]] || exit 0

  case "$command" in
    reboot) systemctl reboot ;;
    poweroff) systemctl poweroff ;;
    logout) logout ;;
  esac
}

choice=$(printf '󰜉  Reboot\n  Power Off\n󰍃  Log Out' | run_rofi)

case "$choice" in
  '󰜉  Reboot')
    confirm_and_run 'Reboot' reboot
    ;;
  '  Power Off')
    confirm_and_run 'Power Off' poweroff
    ;;
  '󰍃  Log Out')
    confirm_and_run 'Log Out' logout
    ;;
esac
