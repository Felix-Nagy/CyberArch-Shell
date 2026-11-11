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
| `--dir PFAD` / `--branch NAME` | anderer Zielordner / Branch |

Optionen hinter den Befehl hängen, z. B. `bash <(curl -fsSL …/setup.sh) --no-fish`.

Wer das Repo schon geklont hat: auf Ubuntu genügt `./install.sh` – er erkennt Ubuntu und lädt `ubuntu/compat.sh`
(dann mit den normalen Fragen; `CYBERARCH_YES=1 ./install.sh` beantwortet sie automatisch).

## Was der Ubuntu-Teil macht

`install.sh` ist der originale Installer. Auf Ubuntu lädt er `ubuntu/compat.sh`, das

- `ppa:cppiber/hyprland` hinzufügt und `ubuntu/packages.txt` per apt installiert,
- aus dem Quellcode baut, was Ubuntu nicht hat (`ubuntu/build-deps.sh`): Astal, AGS 3.1.2, Quickshell, mpvpaper,
  awww, Nerd Fonts – Log: `~/.cache/cyberarch-build/build.log`,
- alle `pacman`-/AUR-Aufrufe des Installers auf apt bzw. diese Builds umleitet (Paket-Mapping Arch → Ubuntu),
- am Ende SDDM startfähig macht und Hyprland + Benutzer im Login vorauswählt.

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
- kein rotes Aufblitzen in kitty bei jedem Enter (fish-Prompt „dangerous“ klingelte bei jedem Prompt)
- SDDM-Video-Hintergrund bleibt unter Qt 6.10 nicht mehr schwarz (`components/login/sddm-theme/Background.qml`)
- Hyprlands autogenerierte `hyprland.lua` wird ersetzt statt erweitert (sonst bleibt deren Warnbanner)
- keine falsche „Rio ohne Shader“-Warnung

## Grenzen

- **CyberSpace-Client** braucht WPE WebKit, das es für Ubuntu nicht gibt (wird im Automatikmodus übersprungen).
- Installation aus einem TTY ohne laufende Grafiksitzung: das cool-retro-term-Profil wird dann erst beim nächsten
  `./install.sh` eingerichtet.

## Aktualisieren

```bash
cd ~/CyberArch-Shell && git pull && ./install.sh
```

Neue Versionen des Originals kommen über „Sync fork“ auf GitHub in diesen Fork.

## Einzelne Builds wiederholen

```bash
bash ~/CyberArch-Shell/ubuntu/build-deps.sh quickshell     # astal astal-gjs ags quickshell mpvpaper awww nerdfonts
```
