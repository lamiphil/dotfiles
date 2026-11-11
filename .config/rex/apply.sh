#!/usr/bin/env bash
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
APP_ID="com.superlogical.rex"
APP_NAME="Rex Beta"
REX="${HOME}/Library/Application Support/com.superlogical.rex/RexServer/Versions/Current/Rex Server.app/Contents/MacOS/rex"
GHOSTTY_CONFIG="${HOME}/.config/ghostty/config"

[[ -x "$REX" ]] || { echo "Rex CLI not found: $REX" >&2; exit 1; }
[[ -f "$GHOSTTY_CONFIG" ]] || { echo "Ghostty config not found: $GHOSTTY_CONFIG" >&2; exit 1; }

mkdir -p "$HOME/.config"
if [[ ! -e "$HOME/.config/rex" ]]; then
  ln -s "$HERE" "$HOME/.config/rex"
elif [[ "$(cd "$HOME/.config/rex" && pwd -P)" != "$HERE" ]]; then
  echo "$HOME/.config/rex already points elsewhere" >&2
  exit 1
fi

"$REX" config check "$HERE/init.lua"

osascript -e "tell application \"$APP_NAME\" to quit" 2>/dev/null || true
sleep 1

defaults write "$APP_ID" rex.client.remoteControl -bool true
defaults write "$APP_ID" Workspace.appearance -string dark
defaults write "$APP_ID" Workspace.paneDensity -string compact
defaults write "$APP_ID" Workspace.showsWindowOnLaunch -bool true
defaults write "$APP_ID" Workspace.terminalFontName -string "BerkeleyMonoNFM-Bold"
defaults write "$APP_ID" Workspace.terminalFontWeight -string bold
defaults write "$APP_ID" Workspace.terminalFontStyle -string regular
defaults write "$APP_ID" Workspace.terminalFontPointSize -float 18
defaults write "$APP_ID" Workspace.terminalFallbackFontNames -array "Noto Color Emoji"
defaults write "$APP_ID" Workspace.terminalStartupCommand -string "/opt/homebrew/bin/fish"
defaults write "$APP_ID" Workspace.terminalOptionKeyBehavior -string compose
defaults write "$APP_ID" Workspace.terminalPaddingColor -string background

open -a "$APP_NAME"

client=""
for _ in {1..30}; do
  client="$("$REX" client ls 2>/dev/null | awk '/Rex Beta/ && !/connection lost/ { id=$NF } END { print id }')"
  [[ -n "$client" ]] && break
  sleep 0.5
done
[[ -n "$client" ]] || { echo "Rex client did not start" >&2; exit 1; }

"$REX" -C "$client" do client.appearance.switch_mode mode=dark >/dev/null

current_theme="$(defaults read "$APP_ID" Workspace.darkThemeID 2>/dev/null || true)"
if [[ "$current_theme" != custom-* ]]; then
  "$REX" -C "$client" do client.theme.import path="$GHOSTTY_CONFIG" >/dev/null
  current_theme="$(defaults read "$APP_ID" Workspace.darkThemeID)"
fi
defaults write "$APP_ID" Workspace.lightThemeID -string "$current_theme"

"$REX" config reload

# Tab-letter listener: restarts with the Rex server, waits while it is down.
AGENT_ID="com.lamiphil.rex-tab-letters"
AGENT_PLIST="$HOME/Library/LaunchAgents/$AGENT_ID.plist"
mkdir -p "$HOME/Library/LaunchAgents"
cat > "$AGENT_PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>$AGENT_ID</string>
  <key>ProgramArguments</key>
  <array>
    <string>$REX</string>
    <string>do</string>
    <string>--autostart=false</string>
    <string>--all</string>
    <string>$HOME/.config/rex/tab-letters.lua</string>
  </array>
  <key>RunAtLoad</key><true/>
  <key>KeepAlive</key><true/>
  <key>ThrottleInterval</key><integer>10</integer>
  <key>StandardErrorPath</key><string>/tmp/$AGENT_ID.log</string>
</dict>
</plist>
EOF
launchctl bootout "gui/$(id -u)/$AGENT_ID" 2>/dev/null || true
launchctl bootstrap "gui/$(id -u)" "$AGENT_PLIST"

echo "Rex configured."
