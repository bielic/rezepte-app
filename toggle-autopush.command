#!/bin/bash
# Toggle Autopush für die App in diesem Ordner.
# Doppelklicken oder via macOS Shortcuts-App mit Tastenkürzel verknüpfen.

# Auto-Erkennung des App-Ordners (gleicher Mechanismus wie setup-autopush.command)
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_NAME=$(basename "$REPO_DIR" | tr '[:upper:]' '[:lower:]' | tr ' ' '-')
LABEL="com.christian.autopush-$APP_NAME"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"

if [[ ! -f "$PLIST" ]]; then
  osascript -e "display notification \"Kein Autopush für '$APP_NAME' eingerichtet. Setup-Script zuerst ausführen.\" with title \"Autopush\""
  echo "Kein LaunchAgent gefunden: $PLIST"
  echo "Drücke Enter zum Schliessen..."
  read
  exit 1
fi

if launchctl list 2>/dev/null | grep -q "$LABEL"; then
  launchctl unload "$PLIST"
  osascript -e "display notification \"Autopush für $APP_NAME PAUSIERT\" with title \"Autopush\" sound name \"Pop\""
  echo "Autopush für $APP_NAME pausiert."
else
  launchctl load "$PLIST"
  osascript -e "display notification \"Autopush für $APP_NAME AKTIV\" with title \"Autopush\" sound name \"Glass\""
  echo "Autopush für $APP_NAME aktiviert."
fi
