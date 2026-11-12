# CyberArch-Shell auf Ubuntu

Ubuntu-Port von [ARCANGEL0/CyberArch-Shell](https://github.com/ARCANGEL0/CyberArch-Shell) (Cyberpunk-2077-HUD für Hyprland).
Getestet auf **Ubuntu 26.04 LTS** (Desktop mit GDM und Server) mit **Hyprland 0.57** aus `ppa:cppiber/hyprland`,
Basis: Upstream **v2.3.26**.

## Einrichten auf einem frisch installierten Ubuntu

Im Terminal:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/Felix-Nagy/CyberArch-Shell/master/ubuntu/setup.sh)
```

Einmal das sudo-Passwort eingeben, danach läuft alles automatisch (beim ersten Mal ca. 30–60 Minuten:
4 GB Download, apt-Pakete, Quellcode-Builds). Am Ende **neu starten** und im netwatch-Login anmelden –
Hyprland mit dem HUD startet. Protokoll: `~/cyberarch-install-<datum>.log`.

| Option | Wirkung |
| --- | --- |
| `--interactive` | alle Fragen des Installers selbst beantworten |
| `--no-fish` | Standard-Shell bleibt bash |
| `--no-upgrade` | kein `apt full-upgrade` vorab |
| `--keep-greeter` | GDM o. ä. behalten (dann kein netwatch-Login / Theme-Lockscreen) |
| `--keep-config` | vorhandene Hyprland-Config (KoolDots, HyDE, ML4W …) nicht ersetzen, Theme nur anhängen |
| `--dir PFAD` / `--branch NAME` | anderer Zielordner / Branch |

Optionen hinter den Befehl hängen, z. B. `bash <(curl -fsSL …/setup.sh) --no-fish`.

Wer das Repo schon geklont hat: auf Ubuntu genügt `./install.sh` – er erkennt Ubuntu und lädt `ubuntu/compat.sh`
(dann mit den normalen Fragen; `CYBERARCH_YES=1 ./install.sh` beantwortet sie automatisch).

## Was der Ubuntu-Teil macht

`install.sh` ist der originale Installer. Auf Ubuntu lädt er `ubuntu/compat.sh`, das

- `ppa:cppiber/hyprland` hinzufügt und `ubuntu/packages.txt` per apt installiert (der PPA-Schlüssel liegt bei, kein `add-apt-repository`),
- aus dem Quellcode baut, was Ubuntu nicht hat (`ubuntu/build-deps.sh`): Astal, AGS 3.1.2, Quickshell, mpvpaper,
  awww, Nerd Fonts – Log: `~/.cache/cyberarch-build/build.log`,
- alle `pacman`-/AUR-Aufrufe des Installers auf apt bzw. diese Builds umleitet (Paket-Mapping Arch → Ubuntu),
- am Ende SDDM startfähig macht und Hyprland + Benutzer im Login vorauswählt,
- maskiert die Benutzerdienste `hypridle` und `hyprpaper`, die Ubuntu global aktiviert (das Theme startet beides selbst),
- richtet einen kleinen Systemdienst `cyberarch-greeter-reaper` ein, der einen nach dem Login hängengebliebenen
  SDDM-Greeter beendet (spart ~1,5 GB RAM).

| Arch | Ubuntu |
| --- | --- |
| pacman/yay/paru | apt + Quellcode-Builds |
| pacman-Hook „PKG INSTALLED“ | apt-Hook `/etc/apt/apt.conf.d/99cyberpunk-pkg-notify` (`ubuntu/apt-pkg-notify`) |
| Update-Banner via `checkupdates`/`yay -Qua` | `apt list --upgradable`, Upgrade-Knopf → `sudo apt full-upgrade` |
| PAM `system-auth` | `/etc/pam.d/qs-lock` mit `common-auth/account/password/session` |
| polkit-gnome | `hyprpolkitagent` (Fallback polkit-gnome) |
| SDDM-Drop-in `10-netwatch.conf` | zusätzlich `99-cyberarch-*.conf` (Ubuntus `budgie-sddm-theme` würde sonst gewinnen) |
| Dolphin mit Plasma-Farben | dunkles KDE-Farbschema `CyberArchDaemon` (`ubuntu/kde-colors.sh`), sonst kaum lesbare Schrift |

Zusätzlich in diesem Fork:

- **SUPER + Enter** öffnet kitty (im `user.lua`-Template)
- **SUPER + SHIFT + 1…0** schiebt das aktive Fenster auf Workspace 1…10 (zusätzlich zu ALT + SHIFT + Zahl)
- **Workspace-Leiste** oben mittig im HUD-Stil (aktiv leuchtet in der Palettenfarbe, belegt rot, Klick wechselt)
- kein rotes Aufblitzen in kitty bei jedem Enter (fish-Prompt „dangerous“ klingelte bei jedem Prompt)
- SDDM-Video-Hintergrund bleibt unter Qt 6.10 nicht mehr schwarz (`components/login/sddm-theme/Background.qml`)
- Hyprlands autogenerierte `hyprland.lua` wird ersetzt statt erweitert (sonst bleibt deren Warnbanner)
- keine falsche „Rio ohne Shader“-Warnung

## Vorhandene Hyprland-Config (Dotfiles)

Lädt `~/.config/hypr/hyprland.lua` schon eine andere Konfiguration, würden deren Leisten und Dienste (Waybar,
swaync …) neben dem HUD weiterlaufen. Der Installer übernimmt deshalb (außer mit `--keep-config`):

- sichert die alte Datei als `hyprland.lua.vor-cyberarch.<zeit>`; danach lädt `hyprland.lua` nur noch das Theme,
- übernimmt Tastaturlayout und Monitore nach `~/.config/hypr/cyberarch-host.lua`,
- beendet Waybar, swaync, dunst, mako, hyprpaper und maskiert deren Benutzerdienste (sonst übernimmt z. B. swaync die
  Benachrichtigungen),
- maskiert nichts systemweit; ein vorhandenes `/etc/sddm.conf` wird gesichert (`/etc/sddm.conf.vor-cyberarch.*`) und auf
  netwatch umgestellt, weil diese Datei alle Drop-ins überstimmt,
- startet das HUD sofort, wenn der Installer in einer laufenden Hyprland-Sitzung läuft.

Den Rückweg schreibt er nach `~/.config/cyberarch/takeover-<zeit>.txt` (Datei zurückkopieren, Dienste `unmask`).
Eigene Ergänzungen gehören in `~/.config/hypr/user.lua` – die Datei bleibt bei Updates unangetastet.

## Bekannte Stolpersteine (alle im Installer abgefangen)

| Problem | Lösung im Installer |
| --- | --- |
| Launchpad (PPA) nicht erreichbar, `add-apt-repository` hängt | PPA-Schlüssel liegt bei (`ubuntu/hyprland-ppa.asc`), Quelle wird direkt eingetragen; bei Ausfall weiter mit installiertem Hyprland, fehlende Pakete aus dem Ubuntu-Archiv |
| sudo-rs reicht `DEBIAN_FRONTEND` nicht durch → unsichtbare debconf-Frage („Default display manager“) | alle apt-Aufrufe mit `sudo env DEBIAN_FRONTEND=noninteractive …`, debconf vorbelegt |
| SDDM startet nach GDM nicht | `/etc/X11/default-display-manager` wird auf sddm gesetzt |
| altes `/etc/sddm.conf` aus Dotfiles erzwingt fremdes Login-Theme | wird gesichert und umgestellt |
| altes AGS v1 in `/usr/local/bin` → HUD startet nicht | `~/.local/bin/ags` zeigt fest auf AGS 3 |
| `/usr/bin/glslc` ist nur ein Link auf glslangValidator → Rio-Build bricht ab | `GLSLANG_VALIDATOR` wird gesetzt |
| `grep -q` in Pipes mit `pipefail` → falsche „nicht gefunden“ | überall `grep … >/dev/null` |
| Codeberg/GitHub kurz nicht erreichbar | Klonen/Downloads mit Wiederholungen |
| apt nach dem ersten Boot blockiert (unattended-upgrades) | apt wartet bis 15 min auf die Sperre |
| Ubuntu aktiviert `hypridle.service` global, das Theme startet hypridle zusätzlich → zwei Lockscreens pro Sperre, einer bleibt mit ~270 MB hängen | `hypridle.service` und `hyprpaper.service` für den Benutzer maskiert; `lock.sh` startet per `flock` nur einen Lockscreen |
| netwatch-Greeter bleibt nach dem Login hängen („Greeter stopping“) und belegt ~1,5 GB RAM | Aufräumdienst `cyberarch-greeter-reaper` beendet ihn, sobald eine Benutzersitzung läuft |
## Grenzen

- **CyberSpace-Client** braucht WPE WebKit, das es für Ubuntu nicht gibt (wird im Automatikmodus übersprungen).
- Installation aus einem TTY ohne laufende Grafiksitzung: das cool-retro-term-Profil wird dann erst beim nächsten
  `./install.sh` eingerichtet.

## Aktualisieren

Updates kommen **nur aus diesem Fork** (`origin` = Felix-Nagy/CyberArch-Shell), nie direkt vom Original.

- Das HUD prüft beim Start die neueste **GitHub-Release** dieses Forks. Ist sie neuer als `VERSION`, erscheint das
  Banner „NEW VERSION … AVAILABLE“; **SUPER+SHIFT+Q** zeigt den Changelog, **UPDATE NOW** führt `updater.sh` aus.
- Von Hand: `cd ~/CyberArch-Shell && ./updater.sh` (spult auf das neueste Release bzw. `master` vor, lokale
  Änderungen werden vorher gestasht).

Versionsschema: `<Version des Originals>.<Ubuntu-Release>`, z. B. `2.3.26.1`.

**Neue Version veröffentlichen** (nach Commits auf `master`):

```bash
cd ~/CyberArch-Shell && ubuntu/release.sh          # 2.3.26.1 -> 2.3.26.2, Changelog aus den Commits
```

Ohne Release meldet das HUD keine Updates. Neues vom Original übernehmen: auf GitHub „Sync fork“ (Konflikte in
`install.sh` prüfen), danach `ubuntu/release.sh <neue-upstream-version>.1`.

## Einzelne Builds wiederholen

```bash
bash ~/CyberArch-Shell/ubuntu/build-deps.sh quickshell     # astal astal-gjs ags quickshell mpvpaper awww nerdfonts
```
