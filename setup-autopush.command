#!/bin/bash
# Doppelklickbares Setup-Script für Autopush nach GitHub.
# Kann beliebig oft ausgeführt werden (idempotent).

set -u  # Variablen müssen definiert sein
# Kein 'set -e' damit das Script bei einzelnen Fehlern weiterläuft

REPO_DIR="/Users/christian.bieli/EigeneApps/Rezepte"
SCRIPTS_DIR="$HOME/.autopush"
LAUNCH_LABEL="com.christian.autopush-rezepte"
PLIST="$HOME/Library/LaunchAgents/$LAUNCH_LABEL.plist"

# Farbige Ausgabe
G=$'\033[32m'; R=$'\033[31m'; Y=$'\033[33m'; B=$'\033[1m'; N=$'\033[0m'

step()  { echo "${B}→${N} $*"; }
ok()    { echo "${G}✓${N} $*"; }
warn()  { echo "${Y}!${N} $*"; }
fail()  { echo "${R}✗${N} $*"; }
die()   { fail "$*"; echo ""; echo "Drücke Enter zum Schliessen..."; read; exit 1; }

clear
echo "${B}╔═══════════════════════════════════════════════════════╗${N}"
echo "${B}║       Autopush Setup für Rezept-App nach GitHub      ║${N}"
echo "${B}╚═══════════════════════════════════════════════════════╝${N}"
echo ""

# ── 1. Apple-Silicon vs Intel-Pfade vorbereiten ─────────────────────
if [[ -x /opt/homebrew/bin/brew ]]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
elif [[ -x /usr/local/bin/brew ]]; then
  eval "$(/usr/local/bin/brew shellenv)"
fi

# ── 2. Homebrew ─────────────────────────────────────────────────────
if ! command -v brew >/dev/null 2>&1; then
  step "Homebrew wird installiert (kann ein paar Minuten dauern)"
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" \
    || die "Homebrew-Installation fehlgeschlagen."
  if [[ -x /opt/homebrew/bin/brew ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  elif [[ -x /usr/local/bin/brew ]]; then
    eval "$(/usr/local/bin/brew shellenv)"
  fi
fi
ok "Homebrew bereit ($(brew --prefix))"

# ── 3. Tools ────────────────────────────────────────────────────────
NEEDED=()
command -v git     >/dev/null 2>&1 || NEEDED+=(git)
command -v gh      >/dev/null 2>&1 || NEEDED+=(gh)
command -v fswatch >/dev/null 2>&1 || NEEDED+=(fswatch)
if [[ ${#NEEDED[@]} -gt 0 ]]; then
  step "Installiere: ${NEEDED[*]}"
  brew install "${NEEDED[@]}" || die "brew install fehlgeschlagen."
fi
ok "git, gh, fswatch installiert"

# ── 4. GitHub-Login ────────────────────────────────────────────────
if ! gh auth status >/dev/null 2>&1; then
  step "GitHub-Login (ein Browser-Fenster öffnet sich)"
  gh auth login --git-protocol https --hostname github.com --web \
    || die "GitHub-Login fehlgeschlagen."
fi
GH_USER=$(gh api user --jq .login 2>/dev/null) || die "Kann GitHub-Account nicht lesen."
ok "Bei GitHub angemeldet als: $GH_USER"

# Git als Credential-Helper auf gh umleiten (damit git push ohne Passwort funktioniert)
gh auth setup-git 2>/dev/null || true

# ── 5. Git-Identity ─────────────────────────────────────────────────
if [[ -z "$(git config --global user.email)" ]]; then
  EMAIL=$(gh api user --jq '.email // empty' 2>/dev/null)
  if [[ -z "$EMAIL" ]]; then
    EMAIL="${GH_USER}@users.noreply.github.com"
  fi
  NAME=$(gh api user --jq '.name // .login' 2>/dev/null)
  [[ -z "$NAME" ]] && NAME="$GH_USER"
  git config --global user.email "$EMAIL"
  git config --global user.name  "$NAME"
fi
ok "Git-Identity: $(git config --global user.name) <$(git config --global user.email)>"

# ── 6. Repo initialisieren / verbinden ─────────────────────────────
cd "$REPO_DIR" || die "Ordner nicht gefunden: $REPO_DIR"

if [[ ! -d .git ]]; then
  step "Initialisiere Git-Repo"
  git init -b main >/dev/null
fi

# .gitignore vorbereiten
GITIGNORE_LINES=(
  ".DS_Store"
  ".autopush/"
  "setup-autopush.command"
)
touch .gitignore
for line in "${GITIGNORE_LINES[@]}"; do
  grep -qxF "$line" .gitignore || echo "$line" >> .gitignore
done

git add -A
git diff --cached --quiet || git commit -m "Setup commit" --quiet

# Remote prüfen / erstellen
if ! git remote get-url origin >/dev/null 2>&1; then
  echo ""
  read -rp "  Name für das GitHub-Repo (Enter für 'rezept-app'): " REPO_NAME
  REPO_NAME=${REPO_NAME:-rezept-app}
  read -rp "  Public oder private? [public/private] (Enter für public): " VIS
  VIS=${VIS:-public}
  step "Erstelle GitHub-Repo: $GH_USER/$REPO_NAME ($VIS)"
  if gh repo view "$GH_USER/$REPO_NAME" >/dev/null 2>&1; then
    warn "Repo existiert bereits, verbinde stattdessen"
    git remote add origin "https://github.com/$GH_USER/$REPO_NAME.git"
  else
    gh repo create "$REPO_NAME" --"$VIS" --source=. --remote=origin \
      || die "Repo-Erstellung fehlgeschlagen."
  fi
fi

# Initial push
step "Pushe nach GitHub"
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo main)
git push -u origin "$CURRENT_BRANCH" 2>&1 | tail -5 \
  || warn "Push hatte Probleme (siehe Meldung oben)"
REPO_URL=$(gh repo view --json url --jq .url 2>/dev/null || echo "")
[[ -n "$REPO_URL" ]] && ok "Repo: $REPO_URL"

# ── 7. Watcher-Script installieren ──────────────────────────────────
step "Installiere Watcher in $SCRIPTS_DIR"
mkdir -p "$SCRIPTS_DIR"
cat > "$SCRIPTS_DIR/autopush-watch.sh" <<'WATCH_EOF'
#!/bin/bash
REPO="${1:-/Users/christian.bieli/EigeneApps/Rezepte}"
cd "$REPO" || { echo "Repo nicht gefunden: $REPO"; exit 1; }
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Watching $REPO ..."

fswatch -o -l 2 --exclude '\.git/' --exclude '\.DS_Store' . | while read num; do
  sleep 3
  if [[ -n "$(git status --porcelain)" ]]; then
    BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo main)
    git add -A
    if git commit -m "Auto-update $(date '+%Y-%m-%d %H:%M')" --quiet 2>/dev/null; then
      if git push origin "$BRANCH" 2>&1 | tail -3; then
        echo "[$(date '+%H:%M:%S')] pushed to $BRANCH"
      fi
    fi
  fi
done
WATCH_EOF
chmod +x "$SCRIPTS_DIR/autopush-watch.sh"
ok "Watcher: $SCRIPTS_DIR/autopush-watch.sh"

# ── 8. LaunchAgent ──────────────────────────────────────────────────
step "Erstelle LaunchAgent: $PLIST"
mkdir -p "$HOME/Library/LaunchAgents"
cat > "$PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>$LAUNCH_LABEL</string>
  <key>ProgramArguments</key>
  <array>
    <string>/bin/bash</string>
    <string>$SCRIPTS_DIR/autopush-watch.sh</string>
    <string>$REPO_DIR</string>
  </array>
  <key>RunAtLoad</key><true/>
  <key>KeepAlive</key><true/>
  <key>StandardOutPath</key><string>/tmp/autopush-rezepte.log</string>
  <key>StandardErrorPath</key><string>/tmp/autopush-rezepte.err</string>
</dict>
</plist>
EOF

launchctl unload "$PLIST" 2>/dev/null || true
launchctl load   "$PLIST" 2>/dev/null && ok "LaunchAgent gestartet"

# ── 9. Zusammenfassung ──────────────────────────────────────────────
echo ""
echo "${G}${B}╔═══════════════════════════════════════════════════════╗${N}"
echo "${G}${B}║              ✓ Setup erfolgreich                     ║${N}"
echo "${G}${B}╚═══════════════════════════════════════════════════════╝${N}"
echo ""
echo "  Repo:    ${REPO_URL:-(siehe github.com/$GH_USER)}"
echo "  Log:     tail -f /tmp/autopush-rezepte.log"
echo "  Stopp:   launchctl unload \"$PLIST\""
echo "  Start:   launchctl load   \"$PLIST\""
echo ""
echo "  Jede Änderung im Rezepte-Ordner wird ab jetzt"
echo "  innerhalb weniger Sekunden automatisch nach GitHub"
echo "  gepusht. GitHub Pages aktualisiert die Live-App"
echo "  dann automatisch (~30–60 Sekunden Verzögerung)."
echo ""
echo "Drücke Enter zum Schliessen..."
read
