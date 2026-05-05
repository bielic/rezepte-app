# Spickzettel – Terminal & GitHub für Anfänger

Alle Befehle einfach kopieren und ins Terminal einfügen (Cmd+V), dann Enter drücken.

---

## Terminal öffnen

Cmd + Leertaste drücken, "Terminal" tippen, Enter. Oder im Finder: **Programme → Dienstprogramme → Terminal**.

---

## Eine neue App auf GitHub bringen (einmalig pro App)

Du brauchst:

1. Einen Ordner mit deiner App (z.B. `~/EigeneApps/Rezepte` oder `~/EigeneApps/Beschwerde`)
2. Die Datei `setup-autopush.command` in diesem Ordner

So gehts:

1. Im Finder den App-Ordner öffnen
2. **Doppelklick auf `setup-autopush.command`**
3. Falls macOS warnt ("nicht überprüfter Entwickler"): **Rechtsklick → Öffnen → Öffnen** bestätigen
4. Im Terminal-Fenster den Anweisungen folgen (Repo-Name, public/private)

Das Script erkennt **automatisch** den Ordner, in dem es liegt – du kannst das gleiche Script für jede App benutzen, ohne etwas anzupassen.

---

## Autopush kontrollieren (für die Rezept-App)

| Was du willst | Befehl im Terminal |
|---|---|
| Live mitschauen, was passiert | `tail -f /tmp/autopush-rezepte.log` |
| (Mitschauen beenden) | Strg + C |
| Pausieren | `launchctl unload ~/Library/LaunchAgents/com.christian.autopush-rezepte.plist` |
| Wieder starten | `launchctl load ~/Library/LaunchAgents/com.christian.autopush-rezepte.plist` |
| Fehler-Log anschauen | `cat /tmp/autopush-rezepte.err` |
| Status prüfen | `launchctl list \| grep autopush` |

---

## Autopush beenden

Drei Stufen, je nachdem wie endgültig:

### Pause (kommt beim nächsten Login automatisch zurück)

```bash
launchctl unload ~/Library/LaunchAgents/com.christian.autopush-rezepte.plist
```

Ideal wenn du nur kurz manuell arbeiten willst und Autopush stört. Nach `launchctl load ...` (siehe Tabelle oben) läuft alles wieder.

### Permanent deaktivieren (auch nach Neustart aus)

```bash
launchctl unload ~/Library/LaunchAgents/com.christian.autopush-rezepte.plist
rm ~/Library/LaunchAgents/com.christian.autopush-rezepte.plist
```

Damit ist der Autopush für diese App weg. Der Watcher-Script und die App selbst bleiben erhalten – falls du es dir später anders überlegst, einfach `setup-autopush.command` nochmal doppelklicken.

### Komplett entfernen (LaunchAgent + Watcher-Script + Logs)

```bash
launchctl unload ~/Library/LaunchAgents/com.christian.autopush-rezepte.plist 2>/dev/null
rm ~/Library/LaunchAgents/com.christian.autopush-rezepte.plist
rm -rf ~/.autopush
rm -f /tmp/autopush-rezepte.log /tmp/autopush-rezepte.err
```

Das räumt alles auf. **Nicht** entfernt werden:

- Der App-Ordner selbst (`~/EigeneApps/Rezepte`) – deine Dateien bleiben
- Das GitHub-Repo – läuft weiter, GitHub Pages auch
- Homebrew, git, gh, fswatch – die Tools bleiben installiert (kannst du behalten, schadet nicht)

### Auch das GitHub-Repo löschen?

Nur falls du auch das Online-Repo nicht mehr willst:

1. github.com → Repo öffnen
2. Tab **Settings**
3. Ganz nach unten scrollen: **Danger Zone → Delete this repository**
4. Repo-Name zur Bestätigung eintippen

Achtung: damit ist die Live-App unter `github.io/...` auch weg. Macht nur Sinn, wenn du wirklich nichts mehr brauchst.

### Für die Beschwerde-App?

Gleiche Befehle, nur **`rezepte`** durch **`beschwerde`** ersetzen:

```bash
launchctl unload ~/Library/LaunchAgents/com.christian.autopush-beschwerde.plist
rm ~/Library/LaunchAgents/com.christian.autopush-beschwerde.plist
```

---

## Wenn du eine zweite App hast (z.B. Beschwerde-App)

**Setup:**

1. Erstelle einen neuen Ordner, z.B. `~/EigeneApps/Beschwerde`
2. Lege deine App-Dateien dort ab (`index.html` etc.)
3. Kopiere `setup-autopush.command` aus dem Rezepte-Ordner in den neuen Ordner
4. Doppelklick im neuen Ordner – fertig

Jede App bekommt automatisch ihr eigenes GitHub-Repo und einen eigenen Autopush-Watcher (Label wird vom Ordnernamen abgeleitet).

**Steuerbefehle für die Beschwerde-App:**

| Was | Befehl |
|---|---|
| Logs | `tail -f /tmp/autopush-beschwerde.log` |
| Pausieren | `launchctl unload ~/Library/LaunchAgents/com.christian.autopush-beschwerde.plist` |
| Starten | `launchctl load ~/Library/LaunchAgents/com.christian.autopush-beschwerde.plist` |

(Wenn dein Ordner anders heisst, ersetze `beschwerde` durch den Ordnernamen in Kleinbuchstaben.)

---

## Manueller Push (falls Autopush mal nicht läuft)

Im Terminal in den App-Ordner wechseln und manuell pushen:

```bash
cd ~/EigeneApps/Rezepte
git add .
git commit -m "Was du geändert hast"
git push
```

Oder für die Beschwerde-App:

```bash
cd ~/EigeneApps/Beschwerde
git add .
git commit -m "Was du geändert hast"
git push
```

---

## Status anschauen

Was hat sich geändert seit dem letzten Push?

```bash
cd ~/EigeneApps/Rezepte
git status
```

Welche Änderungen wurden bisher hochgeladen?

```bash
git log --oneline
```

(Mit q beenden.)

---

## Probleme & Lösungen

**„command not found: brew" oder „command not found: gh"**
→ Doppelklick `setup-autopush.command` erneut. Es installiert fehlende Tools.

**„Authentication failed" beim Push**
→ GitHub-Login abgelaufen. Neu einloggen:

```bash
gh auth login
```

**Autopush scheint nicht zu laufen**
→ Status prüfen:

```bash
launchctl list | grep autopush
```

→ Falls nichts angezeigt wird, neu laden:

```bash
launchctl load ~/Library/LaunchAgents/com.christian.autopush-rezepte.plist
```

**Du hast den App-Ordner verschoben**
→ Setup neu ausführen. Doppelklick `setup-autopush.command` im neuen Pfad.

**Du willst Autopush beenden**
→ Siehe Sektion „Autopush beenden" oben (drei Stufen: Pause / Permanent / Komplett).

---

## GitHub Pages aktivieren (App im Internet sichtbar machen)

Einmalig pro Repo, nach dem ersten Push:

1. Auf [github.com](https://github.com) einloggen
2. Repo öffnen (z.B. `rezept-app`)
3. Tab **Settings** (oben rechts)
4. Links in der Seitenleiste: **Pages**
5. Bei „Branch": von „None" auf `main` umstellen, „Save"
6. 30–60 Sekunden warten
7. Seite neu laden – oben steht jetzt: „Your site is live at https://DEIN-USERNAME.github.io/REPO-NAME/"

Diese URL kannst du auf dem Handy öffnen und „Zum Home-Bildschirm hinzufügen" tippen, dann hast du die App wie eine richtige App.

---

## Dateipfade-Übersicht (zum Nachschauen)

| Was | Wo |
|---|---|
| Apps | `~/EigeneApps/` |
| Rezepte-App | `~/EigeneApps/Rezepte/` |
| Setup-Script (in jedem App-Ordner) | `setup-autopush.command` |
| Autopush-Watcher | `~/.autopush/autopush-watch.sh` |
| LaunchAgents | `~/Library/LaunchAgents/com.christian.autopush-*.plist` |
| Logs (pro App) | `/tmp/autopush-APPNAME.log` |
| GitHub-Login (verwaltet von gh) | `~/.config/gh/` |

`~` ist eine Abkürzung für deinen Benutzer-Ordner (`/Users/christian.bieli`).

---

## Wichtig für deine API-Keys

Die Anthropic/Gemini-Schlüssel der App liegen **nur im Browser** (LocalStorage), nicht in den Dateien. Sie kommen also nicht ins GitHub-Repo. Auf dem Handy musst du sie einmal neu eingeben.

Sollte trotzdem mal ein Schlüssel im Code landen: **sofort auf der Anbieter-Seite widerrufen** (console.anthropic.com bzw. aistudio.google.com), neuen erstellen, und im Repo den alten Commit überschreiben.
