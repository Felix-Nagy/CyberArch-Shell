#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
#  CyberArch-Shell auf frisch installiertem Ubuntu (26.04) einrichten
#
#    bash <(curl -fsSL https://raw.githubusercontent.com/Felix-Nagy/CyberArch-Shell/master/ubuntu/setup.sh)
#    # oder heruntergeladen:  bash setup.sh [optionen]
#
#    --interactive     alle Fragen des Installers selbst beantworten
#    --no-fish         Standard-Shell nicht auf fish umstellen
#    --no-upgrade      kein apt full-upgrade vorab
#    --keep-greeter    vorhandenen Login-Manager (gdm …) behalten, kein SDDM-Login/Theme-Lockscreen
#    --dir PFAD        Zielordner (Standard: ~/CyberArch-Shell)
#    --branch NAME     anderer Branch (Standard: master)
#
#  Ohne --interactive läuft alles automatisch: System-Update · SDDM/netwatch-Login · apt-Hook ·
#  fish · Theme in hyprland.lua · user.lua – am Ende wird NICHT automatisch abgemeldet.
#  Dauer beim ersten Mal ca. 30–60 Minuten (4 GB Download + Quellcode-Builds).
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

REPO="${CYBERARCH_REPO:-https://github.com/Felix-Nagy/CyberArch-Shell}"
BRANCH="master"
DEST="$HOME/CyberArch-Shell"
export CYBERARCH_YES=1
while [ $# -gt 0 ]; do
  case "$1" in
    --interactive)  export CYBERARCH_YES=0 ;;
    --no-fish)      export CYBERARCH_FISH=n ;;
    --no-upgrade)   export CYBERARCH_UPGRADE=n ;;
    --keep-greeter) export CYBERARCH_SDDM=n ;;
    --dir)          DEST="$2"; shift ;;
    --branch)       BRANCH="$2"; shift ;;
    -h|--help)      sed -n '2,19p' "${BASH_SOURCE[0]}" 2>/dev/null | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "unbekannte Option: $1 (siehe --help)"; exit 2 ;;
  esac
  shift
done

grep -qiE '^(ID|ID_LIKE)=.*(ubuntu|debian)' /etc/os-release || { echo "✗ Das ist kein Ubuntu."; exit 1; }
[ "$(id -u)" != 0 ] || { echo "✗ Bitte als normaler Benutzer starten (nicht mit sudo) – das Passwort wird abgefragt."; exit 1; }
[ -r /dev/tty ] || { echo "✗ Bitte in einem Terminal starten."; exit 1; }
FREE_GB=$(df -BG --output=avail "$HOME" | tail -1 | tr -dc 0-9)
[ "${FREE_GB:-0}" -ge 15 ] || { echo "✗ Zu wenig Platz in $HOME (${FREE_GB} GB frei, ≥ 15 GB nötig)."; exit 1; }

echo "▸ sudo-Passwort (einmal für die ganze Installation):"
sudo -v </dev/tty
command -v git >/dev/null || sudo env DEBIAN_FRONTEND=noninteractive apt-get -o DPkg::Lock::Timeout=900 install -y git

if [ -d "$DEST/.git" ]; then
  echo "▸ $DEST existiert – aktualisiere ($BRANCH)"
  git -C "$DEST" fetch -q origin "$BRANCH" && git -C "$DEST" checkout -q "$BRANCH" && git -C "$DEST" merge -q --ff-only "origin/$BRANCH" \
    || echo "  ⚠ konnte nicht aktualisieren (lokale Änderungen?) – nutze vorhandenen Stand"
else
  echo "▸ klone $REPO → $DEST (ca. 4 GB, v. a. Video-Wallpaper)"
  for n in 1 2 3; do
    git clone --branch "$BRANCH" "$REPO" "$DEST" && break
    rm -rf "$DEST"; [ "$n" = 3 ] && { echo "✗ Klonen fehlgeschlagen"; exit 1; }
    echo "  ⚠ neuer Versuch in 20 s"; sleep 20
  done
fi

LOG="$HOME/cyberarch-install-$(date +%Y%m%d-%H%M).log"
echo "▸ Protokoll: $LOG"
cd "$DEST"
set +e
./install.sh 2>&1 | tee "$LOG"
rc=${PIPESTATUS[0]}
set -e
if [ "$rc" = 0 ]; then
  echo
  echo "Fertig. Neu starten, im netwatch-Login anmelden – Hyprland mit CyberArch startet."
else
  echo "✗ Installation mit Fehler $rc beendet – Protokoll: $LOG. Erneut starten setzt dort fort."
fi
exit "$rc"
