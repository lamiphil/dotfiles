#!/bin/sh

FOCUSED_WORKSPACE="$(aerospace list-workspaces --focused)"

for sid in 1 2 3 4 5 6
do
  if [ "$FOCUSED_WORKSPACE" = "$sid" ]; then
    drawing=on
  else
    drawing=off
  fi

  sketchybar --set "workspace.$sid" background.drawing="$drawing"
done
