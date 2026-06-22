#!/bin/bash

# Quit running waybar instances
killall waybar
pkill -f clock-calendar-popup.py || true

# Execute waybar and calendar popup
waybar &
~/.config/waybar/scripts/clock-calendar-popup.py >/tmp/clock-calendar-popup.log 2>&1 &

