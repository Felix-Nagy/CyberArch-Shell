# shellcheck shell=bash
# CyberArch-Shell · Ubuntu-Kompatibilitätsschicht
#
# Wird von install.sh gesourct (nach den Hilfsfunktionen, vor dem ersten pacman-Aufruf),
# wenn das System Ubuntu/Debian ist. Überschreibt innerhalb des Installers:
#   pacman …        -> apt-get / dpkg-query (mit Paket-Mapping)
#   sudo pacman …   -> sudo apt-get …
#   aur_install     -> Quellcode-Builds aus ubuntu/build-deps.sh
# Außerhalb des Installers wird nichts verändert (kein pacman-Shim im PATH).

UBU_DIR="$THEME/ubuntu"
export DEBIAN_FRONTEND=noninteractive
# Rio (sugarloaf) nimmt sonst das erste `glslc` im PATH – auf manchen Systemen ein inkompatibles
# (versteht `-fhlsl_functionality1` nicht). glslangValidator aus glslang-tools funktioniert; Env hat Vorrang.
if [ -z "${GLSLC:-}" ] && command -v glslangValidator >/dev/null 2>&1; then
  export GLSLANG_VALIDATOR="$(command -v glslangValidator)"
fi

# ── Paket-Mapping Arch → Ubuntu ─────────────────────────────────────────────
#   ""        -> auf Ubuntu nicht nötig (lib32, Teil eines anderen Pakets …)
#   "@step"   -> wird aus dem Quellcode gebaut (ubuntu/build-deps.sh <step>)
#   "a b"     -> diese Ubuntu-Pakete
declare -gA UBU_MAP=(
  [hyprland]="hyprland" [hyprgraphics]="" [hyprland-guiutils]="hyprland-guiutils" [hyprlock]="hyprlock"
  [hyprtoolkit]="" [hyprwire]="" [hyprlang]="" [hypridle]="hypridle"
  [xdg-desktop-portal-hyprland]="xdg-desktop-portal-hyprland xdg-desktop-portal-gtk"
  [lua]="lua5.4" [lua54]="lua5.4" [gcc]="gcc" [gcc-libs]="" [glibc]="" [ffmpeg4.4]=""
  [chromaprint]="libchromaprint-tools" [xorg-xwayland]="xwayland"
  [networkmanager]="network-manager" [bluez-utils]="bluez" [libnotify]="libnotify-bin"
  [kvantum]="qt6-style-kvantum" [kvantum-qt5]="qt5-style-kvantum" [fuse2]="libfuse2t64"
  [pacman-contrib]="" [cronie]="cron" [libcdio]="libcdio-utils" [libcdio-paranoia]="cdparanoia"
  [base-devel]="build-essential" [python]="python3" [python-pillow]="python3-pil"
  [mesa]="libgl1-mesa-dri mesa-vulkan-drivers libegl-mesa0" [libdrm]="libdrm2"
  [vulkan-radeon]="mesa-vulkan-drivers" [vulkan-intel]="mesa-vulkan-drivers" [vulkan-swrast]="mesa-vulkan-drivers"
  [intel-media-driver]="intel-media-va-driver" [nvidia-open]="" [nvidia-utils]=""
  [libpulse]="libpulse0 pulseaudio-utils" [sox]="sox libsox-fmt-all" [gst-plugin-pipewire]="gstreamer1.0-pipewire"
  [gst-plugins-good]="gstreamer1.0-plugins-good" [gst-plugins-base]="gstreamer1.0-plugins-base"
  [pipewire-x11-bell]="" [pipewire-zeroconf]="libspa-0.2-modules"
  [ttf-jetbrains-mono]="fonts-jetbrains-mono" [otf-fantasque-sans-mono]="fonts-fantasque-sans"
  [ttf-firacode-nerd]="@nerdfonts" [ttf-nerd-fonts-symbols]="@nerdfonts" [ttf-nerd-fonts-symbols-mono]="@nerdfonts"
  [yay]="" [paru]=""
  [aylurs-gtk-shell]="@ags" [libastal-gjs-git]="@astal-gjs"
  [libastal-notifd-git]="@astal" [libastal-wireplumber-git]="@astal" [libastal-mpris-git]="@astal"
  [mpvpaper]="@mpvpaper" [awww]="@awww" [quickshell]="@quickshell" [quickshell-git]="@quickshell"
  [qt6-base]="libqt6core6t64 libqt6gui6 qt6-qpa-plugins" [qt6-declarative]="qml6-module-qtquick qml6-module-qtquick-window qml6-module-qtqml-workerscript"
  [qt6-multimedia]="libqt6multimedia6 qml6-module-qtmultimedia" [qt6-multimedia-ffmpeg]=""
  [qt6-svg]="libqt6svg6" [qt6-wayland]="qt6-wayland" [qt6-5compat]="qml6-module-qt5compat-graphicaleffects"
  [rust]="cargo rustc" [llvm-libs]="" [librashader]="" [freetype2]="libfreetype-dev"
  [libxkbcommon]="libxkbcommon-dev" [wayland]="libwayland-dev" [vulkan-icd-loader]="libvulkan1 libvulkan-dev"
  [wpewebkit]=""
)

ubu_map() { # Arch-Paketname -> Ubuntu-Namen (oder @step / leer)
  local p="$1"
  case "$p" in lib32-*) return 0 ;; esac
  if [[ -v UBU_MAP[$p] ]]; then printf '%s' "${UBU_MAP[$p]}"; else printf '%s' "$p"; fi
}

# Ist ein (Arch-)Paket auf Ubuntu erfüllt?
ubu_has() {
  local m d; m="$(ubu_map "$1")"
  [ -z "$m" ] && return 0
  if [[ "$m" == @* ]]; then ubu_built "${m#@}"; return; fi
  for d in $m; do
    dpkg-query -W -f '${Status}' "$d" 2>/dev/null | grep 'install ok installed' >/dev/null || return 1
  done
}

ubu_built() { # Prüft, ob ein Quellcode-Build schon installiert ist
  case "$1" in
    ags)        command -v ags >/dev/null && [ -d /usr/share/ags/js ] ;;
    astal)      [ -n "$(ls /usr/lib/*/girepository-1.0/AstalNotifd-0.1.typelib /usr/lib/girepository-1.0/AstalNotifd-0.1.typelib 2>/dev/null)" ] ;;
    astal-gjs)  [ -d /usr/share/astal/gjs ] ;;
    quickshell) command -v qs >/dev/null ;;
    mpvpaper)   command -v mpvpaper >/dev/null ;;
    awww)       command -v awww >/dev/null ;;
    nerdfonts)  fc-list 2>/dev/null | grep -i 'Symbols Nerd Font' >/dev/null ;;  # kein grep -q: SIGPIPE + pipefail
    *) return 1 ;;
  esac
}

ubu_build() { # ubu_build <step>…  (Reihenfolge ist wichtig: astal vor astal-gjs vor ags)
  local want=() s
  for s in astal astal-gjs ags quickshell mpvpaper awww nerdfonts; do
    case " $* " in *" $s "*) ubu_built "$s" || want+=("$s") ;; esac
  done
  [ "${#want[@]}" -eq 0 ] && return 0
  step "Quellcode-Build: ${want[*]}"
  bash "$UBU_DIR/build-deps.sh" "${want[@]}"
}

# apt-Installation einer Liste von Arch-Namen
# apt ohne Rückfragen: sudo-rs (Ubuntu 26.04) reicht bei `sudo -E` DEBIAN_FRONTEND nicht durch →
# sonst hängt z. B. die sddm-Frage „Default display manager“ unsichtbar hinter dem Installer.
ubu_apt() {
  command sudo env DEBIAN_FRONTEND=noninteractive NEEDRESTART_MODE=a \
    apt-get -o DPkg::Lock::Timeout=900 -o Dpkg::Options::=--force-confdef -o Dpkg::Options::=--force-confold \
    "${UBU_APT_PIN[@]}" "$@"
}
UBU_APT_PIN=()

ubu_install() {
  local debs=() steps=() p m
  for p in "$@"; do
    case "$p" in -*) continue ;; esac
    m="$(ubu_map "$p")"
    [ -z "$m" ] && continue
    if [[ "$m" == @* ]]; then steps+=("${m#@}"); else
      for p in $m; do apt-cache show "$p" >/dev/null 2>&1 && debs+=("$p") || warn "kein Ubuntu-Paket für $p |::| übersprungen"; done
    fi
  done
  local rc=0 rest=() d
  for d in "${debs[@]}"; do
    # sddm ohne Recommends: sonst kommt budgie-sddm-theme mit und übernimmt den Greeter
    if [ "$d" = sddm ]; then ubu_apt install -y --no-install-recommends sddm xserver-xorg-core xserver-xorg-input-libinput || rc=1
    else rest+=("$d"); fi
  done
  debs=("${rest[@]}")
  if [ "${#debs[@]}" -gt 0 ]; then ubu_apt install -y --no-upgrade "${debs[@]}" || rc=1; fi
  if [ "${#steps[@]}" -gt 0 ]; then ubu_build "${steps[@]}" || rc=1; fi
  return $rc
}

# ── pacman-Emulation (nur innerhalb des Installers) ────────────────────────
pacman() {
  local op="${1:-}"; shift || true
  case "$op" in
    -S|-S\ *)
      ubu_install "$@" ;;
    -Sy) ubu_apt update -qq ;;
    -Syu|-Syyu) ubu_apt update && ubu_apt full-upgrade -y ;;
    -Q|-Qq)
      local p rc=0 v
      for p in "$@"; do
        if ubu_has "$p"; then
          if [ "$op" = -Qq ]; then echo "$p"; else
            v="$(dpkg-query -W -f '${Version}' "$(ubu_map "$p" | awk '{print $1}')" 2>/dev/null)"
            echo "$p ${v:-0}"
          fi
        else rc=1; fi
      done
      return $rc ;;
    -Qg) return 1 ;;
    -Si)
      local v; v="$(apt-cache policy "$(ubu_map "$1" | awk '{print $1}')" 2>/dev/null | sed -n 's/^ *Candidate: //p')"
      [ -n "$v" ] && [ "$v" != "(none)" ] && printf 'Version         : %s\n' "$v" ;;
    *) warn "pacman $op nicht emuliert |::| ignoriert"; return 0 ;;
  esac
}

sudo() {
  if [ "${1:-}" = pacman ]; then shift; pacman "$@"; return; fi
  # pacman-Hook -> apt-Hook umleiten
  if [ "${1:-}" = tee ] && [[ "${2:-}" == /etc/pacman.d/hooks/* ]]; then
    cat >/dev/null
    ubu_apt_hook; return
  fi
  # SDDM-Drop-ins: Ubuntu bringt 50-ubuntu-budgie.conf mit, das 10-netwatch.conf überstimmt
  # -> zusätzlich als 99-cyberarch-*.conf ablegen, damit die Theme-Einstellungen gewinnen
  if [ "${1:-}" = tee ] && [[ "${2:-}" == /etc/sddm.conf.d/*.conf ]]; then
    local f="$2" body; body="$(cat)"
    printf '%s\n' "$body" | command sudo tee "$f" >/dev/null || return 1
    printf '%s\n' "$body" | command sudo tee "/etc/sddm.conf.d/99-cyberarch-$(basename "$f")" >/dev/null
    ubu_sddm_overrides
    return
  fi
  # Debian/Ubuntu: sddm.service startet nur, wenn /etc/X11/default-display-manager auf sddm zeigt
  # (ExecStartPre-Prüfung). Der Installer stellt nur den systemd-Alias um → hier mitziehen.
  if [ "${1:-}" = systemctl ] && [[ " $* " == *" enable "* ]] && [[ " $* " == *" sddm"* ]]; then
    command sudo "$@" || return
    echo /usr/bin/sddm | command sudo tee /etc/X11/default-display-manager >/dev/null
    return 0
  fi
  command sudo "$@"
}

pkg_has() { ubu_has "$1"; }

aur_install() { # Label + Arch/AUR-Namen
  local label="$1"; shift
  if ubu_install "$@"; then ok "$label installed"; return 0; fi
  fatal "$label — Ubuntu-Build fehlgeschlagen: $*" \
    "Log: ${CYBER_SRC:-$HOME/.cache/cyberarch-build}/build.log" \
    "Einzeln neu bauen:  bash $UBU_DIR/build-deps.sh <schritt>"
}

pac_install() {
  local label="$1"; shift
  [ "$#" -eq 0 ] && return 0
  if ubu_install "$@"; then ok "$label installed"; return 0; fi
  fatal "$label — apt konnte nicht alles installieren." "Manuell prüfen:  sudo apt-get install …"
}

# Ubuntu-spezifische SDDM-Korrekturen (überstimmt u. a. budgie-sddm-theme)
ubu_sddm_overrides() {
  command sudo tee /etc/sddm.conf.d/99-cyberarch-ubuntu.conf >/dev/null <<'EOF'
# CyberArch-Shell (Ubuntu): netwatch-Greeter ohne Bildschirmtastatur,
# Theme darf seine lokalen Dateien (News-Cache, Standort) per XMLHttpRequest lesen
[General]
InputMethod=
GreeterEnvironment=QML_XHR_ALLOW_FILE_READ=1

[X11]
DisplayCommand=/usr/share/sddm/scripts/Xsetup
EOF
}

# apt-Gegenstück zum pacman-Hook (Street-Cred-Animation bei neu installierten Paketen)
ubu_apt_hook() {
  local conf=/etc/apt/apt.conf.d/99cyberpunk-pkg-notify
  command sudo tee "$conf" >/dev/null <<EOF
// CyberArch-Shell: HUD-Animation bei neu installierten Paketen
DPkg::Pre-Install-Pkgs { "$CANON/ubuntu/apt-pkg-notify pre || true"; };
DPkg::Post-Invoke { "$CANON/ubuntu/apt-pkg-notify post || true"; };
EOF
  ok "apt-Hook → $conf"
}

# ── Ubuntu-Vorbereitung (einmalig vor dem eigentlichen Installer) ──────────
ubu_prepare() {
  hdr "UBUNTU · Vorbereitung"
  # abgebrochene Paketinstallation (z. B. aus einem früheren Lauf) erst fertig konfigurieren
  command sudo env DEBIAN_FRONTEND=noninteractive dpkg --configure -a >/dev/null 2>&1 || true
  # SDDM als Login-Manager vorauswählen (sonst fragt debconf beim Installieren von sddm)
  if [ "${CYBERARCH_SDDM:-y}" != n ]; then
    printf 'sddm shared/default-x-display-manager select sddm\ngdm3 shared/default-x-display-manager select sddm\n' \
      | command sudo debconf-set-selections 2>/dev/null || true
  fi
  if ! grep -rqs 'cppiber/hyprland' /etc/apt/sources.list.d/; then
    # Direkt mit mitgeliefertem Schlüssel (ubuntu/hyprland-ppa.asc, Fingerprint A54D23B6…F0CCF48E) statt
    # add-apt-repository: das fragt die Launchpad-API und hing beim Test unbegrenzt, als Launchpad nicht antwortete.
    step "Hyprland-PPA (ppa:cppiber/hyprland) hinzufügen"
    local codename; codename="$(. /etc/os-release; echo "${VERSION_CODENAME:-resolute}")"
    command sudo install -d -m 755 /etc/apt/keyrings
    command sudo install -m 644 "$UBU_DIR/hyprland-ppa.asc" /etc/apt/keyrings/cppiber-hyprland.asc
    printf 'Types: deb\nURIs: https://ppa.launchpadcontent.net/cppiber/hyprland/ubuntu/\nSuites: %s\nComponents: main\nSigned-By: /etc/apt/keyrings/cppiber-hyprland.asc\n' "$codename" \
      | command sudo tee "/etc/apt/sources.list.d/cppiber-ubuntu-hyprland-$codename.sources" >/dev/null
    ok "PPA eingetragen ($codename)"
  else ok "Hyprland-PPA vorhanden"; fi
  local upd; upd="$(mktemp)"
  ubu_apt -o Acquire::http::Timeout=30 -o Acquire::https::Timeout=30 -o Acquire::Retries=3 update 2>&1 | tee "$upd" | grep -E '^(E|W):' || true
  local hv; hv="$(dpkg-query -W -f '${Version}' hyprland 2>/dev/null || true)"
  # PPA erreichbar? Am Ergebnis von apt update messen – apt-cache zeigt das PPA auch aus alten Listen an.
  # (kein grep -q in Pipes: bricht früh ab → SIGPIPE → mit pipefail fälschlich „nicht gefunden“)
  if ! grep 'ppa.launchpadcontent.net/cppiber' "$upd" | grep -E 'Fail|Err|error' >/dev/null \
     && apt-cache policy hyprland 2>/dev/null | grep 'ppa.launchpadcontent.net/cppiber' >/dev/null; then
    :
  elif [ -n "$hv" ] && dpkg --compare-versions "$hv" ge 0.56; then
    warn "Hyprland-PPA gerade nicht erreichbar |::| nutze installiertes Hyprland $hv, fehlende Pakete aus dem Ubuntu-Archiv"
    # nur für die apt-Aufrufe dieses Installers: PPA nachrangig, damit apt das Ubuntu-Archiv nimmt
    local pin; pin="$(mktemp)"; chmod 644 "$pin"
    printf 'Package: *\nPin: origin ppa.launchpadcontent.net\nPin-Priority: 1\n' > "$pin"
    UBU_APT_PIN=(-o "Dir::Etc::Preferences=$pin")
  else
    fatal "Das Hyprland-PPA ist gerade nicht erreichbar (ppa.launchpadcontent.net)." \
      "Ohne PPA gibt es kein aktuelles Hyprland (≥ 0.56) für Ubuntu." \
      "Prüfen:  curl -I https://ppa.launchpadcontent.net/cppiber/hyprland/ubuntu/" \
      "Später einfach erneut starten – bereits erledigte Schritte werden übersprungen."
  fi
  rm -f "$upd"
  step "Build- und Laufzeitpakete (ubuntu/packages.txt)"
  # shellcheck disable=SC2046
  ubu_apt install -y --no-upgrade $(grep -v '^#' "$UBU_DIR/packages.txt") \
    || fatal "apt-get install fehlgeschlagen" "Log oben lesen, dann ./install.sh erneut starten"
  ok "Ubuntu-Pakete installiert"
  ubu_build astal astal-gjs ags quickshell mpvpaper awww nerdfonts || fatal "Quellcode-Build fehlgeschlagen" \
    "Log: ${CYBER_SRC:-$HOME/.cache/cyberarch-build}/build.log"
  ok "AGS/Astal/Quickshell/mpvpaper/awww bereit"
  # launch-theme startet ~/.local/bin/ags. Der Installer verlinkt sonst das erste `ags` im PATH – bei
  # manchen Dotfiles ein altes AGS v1 in /usr/local/bin („Unable to find AGS entry script“) → HUD startet nicht.
  if [ -x /usr/bin/ags ]; then
    mkdir -p "$HOME/.local/bin" && ln -sfn /usr/bin/ags "$HOME/.local/bin/ags" && ok "~/.local/bin/ags → /usr/bin/ags (AGS 3)"
  fi
  # KDE-Apps (Dolphin = SUPER+E) bekommen ein dunkles Farbschema passend zu Kvantum "Daemon"
  bash "$UBU_DIR/kde-colors.sh" && ok "KDE-Farbschema CyberArchDaemon gesetzt"
  # PAM: Ubuntu hat kein system-auth -> qs-lock vorab mit common-* anlegen
  if [ ! -f /etc/pam.d/qs-lock ]; then
    printf '@include common-auth\n@include common-account\n@include common-password\n@include common-session\n' \
      | command sudo tee /etc/pam.d/qs-lock >/dev/null && ok "PAM qs-lock → common-auth"
  fi
}

# ── Automatikmodus (CYBERARCH_YES=1): beantwortet die y/N-Fragen von install.sh ──
# Jede Frage steht hinter einem hdr "…" → aktuellen Abschnitt merken und danach antworten.
# Nur die Installer-Prompts (`read -r ans`) werden beantwortet, alle anderen read-Aufrufe laufen normal.
ubu_auto_answer() {
  case "$1" in
    "SYSTEM UPGRADE")                 echo "${CYBERARCH_UPGRADE:-y}" ;;
    "HYPRLAND CORE")                  echo n ;;   # Hyprland kommt aus dem PPA, kein pacman-Update
    "MISSING PACKAGES")               echo y ;;
    "GREETER CHECK")                  echo "${CYBERARCH_SDDM:-y}" ;;   # gdm & Co. → SDDM (netwatch)
    "PACMAN HOOK")                    echo y ;;   # → apt-Hook
    "CYBERSPACE · net client")        echo n ;;   # braucht WPE WebKit, gibt es für Ubuntu nicht
    "DEFAULT SHELL · fish")           echo "${CYBERARCH_FISH:-y}" ;;
    "DESKTOP SHELL · takeover check") echo y ;;
    "HYPRLAND · load the theme")      echo y ;;
    "HYPRLAND · user.lua template")   echo y ;;
    *)                                echo n ;;   # u. a. „jetzt ausloggen?“ am Ende
  esac
}
if [ "${CYBERARCH_YES:-0}" = 1 ]; then
  eval "__ubu_orig_hdr() $(declare -f hdr | tail -n +2)"
  hdr() { UBU_SECTION="$1"; __ubu_orig_hdr "$@"; }
  read() {
    if [ "$#" -eq 2 ] && [ "$1" = -r ] && [ "$2" = ans ]; then
      ans="$(ubu_auto_answer "${UBU_SECTION:-}")"
      printf '%s  \033[2m(automatisch)\033[0m\n' "$ans"
      return 0
    fi
    builtin read "$@"
  }
fi

# ── Nacharbeiten am Ende von install.sh ─────────────────────────────────────
# Der netwatch-Greeter (Qt + Video) bleibt nach dem Login oft hängen ("Greeter stopping" → "Process crashed")
# und hält dann ~1,5 GB RAM. Kleiner Systemdienst: sobald auf seat0 eine Benutzersitzung läuft, wird ein
# übrig gebliebener Greeter beendet. Am Login-Bildschirm (keine Sitzung) tut er nichts.
ubu_greeter_reaper() {
  command -v systemctl >/dev/null 2>&1 || return 0
  [ -d /var/lib/sddm ] || return 0
  command sudo install -d /usr/local/libexec
  command sudo tee /usr/local/libexec/cyberarch-greeter-reaper >/dev/null <<'EOF2'
#!/bin/sh
# beendet einen hängengebliebenen SDDM-Greeter, sobald auf seat0 eine Benutzersitzung läuft
while sleep 20; do
  pgrep -u sddm -x sddm-greeter-qt6 >/dev/null || continue
  loginctl list-sessions --no-legend | awk '$4=="seat0" && $6=="user" {f=1} END{exit !f}' || continue
  sleep 10   # dem Greeter Zeit für ein sauberes Ende geben
  pkill -TERM -u sddm -x sddm-greeter-qt6; sleep 3
  pkill -KILL -u sddm -x sddm-greeter-qt6
done
EOF2
  command sudo chmod 755 /usr/local/libexec/cyberarch-greeter-reaper
  command sudo tee /etc/systemd/system/cyberarch-greeter-reaper.service >/dev/null <<'EOF2'
[Unit]
Description=CyberArch: hängengebliebenen SDDM-Greeter nach dem Login beenden
After=sddm.service

[Service]
ExecStart=/usr/local/libexec/cyberarch-greeter-reaper
Nice=10

[Install]
WantedBy=multi-user.target
EOF2
  command sudo systemctl daemon-reload
  command sudo systemctl enable --now cyberarch-greeter-reaper.service >/dev/null 2>&1 || true
  ok "Greeter-Aufräumdienst aktiv (spart ~1,5 GB RAM nach dem Login)"
}

# ── WallpaperDaemon.sh: Theme-Wallpaper gewinnt gegen eine ältere SUPER+W-Auswahl ─────────────
# Upstream liest bei jedem Resume (hypridle/LidSwitch) zuerst die KoolDots-Dateien (SUPER+W). Das
# Theme speichert seine Wahl in ~/.config/cyberarch/wallpaper.lua. Ohne Fix überschreibt eine alte
# SUPER+W-Auswahl das Theme-Wallpaper nach jedem Schlafen. ubuntu/WallpaperDaemon.sh entscheidet
# anhand der Änderungszeit, welche Quelle neuer ist. Das Original wird einmal als *.orig-cyberarch gesichert.
ubu_wallpaper_daemon() {
  local src="$UBU_DIR/WallpaperDaemon.sh" dst="$HOME/.config/hypr/scripts/WallpaperDaemon.sh"
  [ -f "$src" ] || return 0
  mkdir -p "$(dirname "$dst")"
  if [ -f "$dst" ] && ! cmp -s "$src" "$dst" && [ ! -f "$dst.orig-cyberarch" ]; then
    cp -p "$dst" "$dst.orig-cyberarch"
  fi
  if install -m 755 "$src" "$dst"; then
    ok "WallpaperDaemon.sh: Theme-Wallpaper hat Vorrang vor älterer SUPER+W-Auswahl"
  else
    warn "WallpaperDaemon.sh konnte nicht installiert werden |::| Wallpaper springt nach Schlafen evtl. zurück"
  fi
}

ubu_finish() {
  hdr "UBUNTU · Abschluss"
  if [ "$(readlink -f /etc/systemd/system/display-manager.service 2>/dev/null)" = "$(readlink -f /usr/lib/systemd/system/sddm.service 2>/dev/null)" ]; then
    # sddm.service prüft beim Start /etc/X11/default-display-manager (stünde nach GDM sonst auf gdm3)
    echo /usr/bin/sddm | command sudo tee /etc/X11/default-display-manager >/dev/null
    command sudo systemctl reset-failed sddm 2>/dev/null || true
    ok "SDDM startet beim nächsten Boot (default-display-manager → sddm)"
    # /etc/sddm.conf wird NACH allen sddm.conf.d-Drop-ins gelesen und gewinnt immer. Andere Dotfiles
    # (z. B. KoolDots: Current=simple_sddm_2, InputMethod=qtvirtualkeyboard) überstimmen sonst netwatch.
    if [ -f /etc/sddm.conf ] && grep -E '^[[:space:]]*(Current|InputMethod|GreeterEnvironment)[[:space:]]*=' /etc/sddm.conf >/dev/null; then
      local bak; bak="/etc/sddm.conf.vor-cyberarch.$(date +%s)"
      command sudo cp -p /etc/sddm.conf "$bak"
      command sudo sed -i -E \
        -e 's/^[[:space:]]*Current[[:space:]]*=.*/Current=netwatch/' \
        -e 's/^[[:space:]]*InputMethod[[:space:]]*=.*/InputMethod=/' \
        -e 's/^[[:space:]]*GreeterEnvironment[[:space:]]*=.*/GreeterEnvironment=QML_XHR_ALLOW_FILE_READ=1/' \
        /etc/sddm.conf
      ok "/etc/sddm.conf auf netwatch umgestellt (vorher: $bak)"
    fi
  fi
  if [ -d /var/lib/sddm ] && [ -f /usr/share/wayland-sessions/hyprland.desktop ]; then
    # beim ersten Login Hyprland + diesen Benutzer vorauswählen (sonst ggf. GNOME)
    printf '[Last]\nUser=%s\nSession=/usr/share/wayland-sessions/hyprland.desktop\n' "$(id -un)" \
      | command sudo tee /var/lib/sddm/state.conf >/dev/null
    command sudo chown sddm:sddm /var/lib/sddm/state.conf 2>/dev/null || true
    ok "SDDM wählt Hyprland + $(id -un) vor"
  fi
  ubu_greeter_reaper
  ubu_wallpaper_daemon
  ubu_user_units
  ubu_takeover
  ubu_start_hud
}

# Ubuntu-Pakete aktivieren hypridle.service und hyprpaper.service global (graphical-session.target).
# theme.lua startet hypridle aber selbst ("pgrep hypridle || hypridle"); beide starten gleichzeitig,
# der pgrep-Schutz verliert das Rennen → zwei hypridle → beim Sperren zwei Lockscreens, der zweite
# bekommt die Sperre nie und bleibt mit ~270 MB im Speicher. Wallpaper kommt von awww/mpvpaper,
# hyprpaper läuft nur doppelt mit. Beide Dienste für diesen Benutzer maskieren (umkehrbar: unmask).
ubu_user_units() {
  local u
  for u in hypridle hyprpaper; do
    [ -e "/usr/lib/systemd/user/$u.service" ] || continue
    [ "$(systemctl --user is-enabled "$u.service" 2>/dev/null)" = masked ] && continue
    systemctl --user stop "$u.service" >/dev/null 2>&1 || true
    systemctl --user mask "$u.service" >/dev/null 2>&1 \
      && ok "Benutzerdienst $u maskiert (Theme startet hypridle selbst, Wallpaper über awww)" \
      || warn "$u.service ließ sich nicht maskieren |::| systemctl --user mask $u.service"
  done
  # Installer in laufender Sitzung: nach dem Stoppen des Dienstes hypridle wie theme.lua neu starten
  if [ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ] && command -v hypridle >/dev/null && ! pgrep -x hypridle >/dev/null; then
    setsid -f hypridle >/dev/null 2>&1 || true
  fi
}

# ── Übernahme einer vorhandenen Hyprland-Config (KoolDots, HyDE, ML4W …) ──────
# install.sh hängt das Theme nur HINTER eine bestehende hyprland.lua. Deren Autostarts (waybar, swaync …)
# laufen dann weiter, und swaync nimmt dem HUD die Benachrichtigungen weg. Beim Host-Test (KoolDots) musste
# das von Hand gelöst werden. Hier: Config sichern, nur noch Theme laden, Tastatur + Monitore übernehmen,
# konkurrierende Leisten/Benachrichtigungsdienste stoppen (nur für diesen Benutzer, umkehrbar).
#   CYBERARCH_TAKEOVER=y|n   (Standard: y im Automatikmodus, sonst Rückfrage)
ubu_takeover() {
  local hd="$HOME/.config/hypr" hl="$HOME/.config/hypr/hyprland.lua"
  [ -f "$hl" ] || return 0
  # Zeilen, die nicht zum Theme-Loader gehören (Kommentare/Leerzeilen ignoriert)
  local foreign
  foreign="$(grep -vE '^[[:space:]]*(--.*)?$' "$hl" | grep -cvE 'themes/cyberpunk/\?\.lua|^require\("(theme|user|cyberarch-host)"\)[[:space:]]*$' || true)"
  [ "${foreign:-0}" -gt 0 ] || return 0

  hdr "UBUNTU · vorhandene Hyprland-Config übernehmen"
  printf "  ${DIM}Deine hyprland.lua lädt noch eine andere Konfiguration (%s Zeilen). Deren Leisten und Dienste\n" "$foreign"
  printf "  würden neben dem HUD weiterlaufen. Sie wird gesichert, danach lädt hyprland.lua nur noch das Theme.${R}\n"
  local ans="${CYBERARCH_TAKEOVER:-}"
  if [ -z "$ans" ]; then
    if [ "${CYBERARCH_YES:-0}" = 1 ]; then ans=y
    else printf "[!] Vorhandene Config sichern und durch das Theme ersetzen? (y/N) "; builtin read -r ans </dev/tty || ans=n; fi
  fi
  case "$ans" in [yY]*) ;; *) warn "übersprungen |::| Theme bleibt hinter deiner Config angehängt"; return 0 ;; esac

  local ts bak note host
  ts="$(date +%Y%m%d-%H%M%S)"; bak="$hl.vor-cyberarch.$ts"
  note="$HOME/.config/cyberarch/takeover-$ts.txt"; host="$hd/cyberarch-host.lua"
  mkdir -p "$HOME/.config/cyberarch"
  cp -p "$hl" "$bak" && ok "gesichert → $bak"
  { echo "CyberArch-Übernahme $ts – rückgängig machen:"; echo "  cp -p '$bak' '$hl'"; } > "$note"

  # Tastatur + Monitore übernehmen: live aus Hyprland, sonst aus der alten Config
  local live=0 kb="" kv=""
  [ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ] && command -v hyprctl >/dev/null && hyprctl version >/dev/null 2>&1 && live=1
  if [ "$live" = 1 ] && command -v jq >/dev/null; then
    kb="$(hyprctl getoption input:kb_layout -j 2>/dev/null | jq -r '.str // empty')"
    kv="$(hyprctl getoption input:kb_variant -j 2>/dev/null | jq -r '.str // empty')"
  fi
  if [ -z "$kb" ]; then
    kb="$(grep -rhoE 'kb_layout[[:space:]]*=[[:space:]]*"[^"]+"' "$hd" --include='*.lua' 2>/dev/null | grep -v themes/ | head -n1 | sed -E 's/.*"([^"]+)".*/\1/' || true)"
  fi
  {
    echo "-- Von der vorherigen Hyprland-Config übernommen ($ts). Sicherung: $bak"
    [ -n "$kb" ] && [ "$kb" != "[[EMPTY]]" ] && printf 'hl.config({ input = { kb_layout = "%s"%s } })\n' "$kb" \
      "$( [ -n "$kv" ] && [ "$kv" != "[[EMPTY]]" ] && printf ', kb_variant = "%s"' "$kv")"
    if [ "$live" = 1 ] && command -v jq >/dev/null; then
      hyprctl monitors -j 2>/dev/null | jq -r '.[] | "hl.monitor({ output = \"\(.name)\", mode = \"\(.width)x\(.height)@\(.refreshRate * 1000 | round / 1000)\", position = \"\(.x)x\(.y)\", scale = \(.scale) })"'
    fi
  } > "$host"
  ok "Tastatur${kb:+ ($kb)} und Monitore → $host"

  printf '%s\n' "-- CyberArch-Shell (vorherige Config: $bak)" \
    'package.path = os.getenv("HOME") .. "/.config/hypr/themes/cyberpunk/?.lua;" .. os.getenv("HOME") .. "/.config/hypr/?.lua;" .. (package.path or "")' \
    'require("theme")' 'require("user")' 'require("cyberarch-host")' > "$hl"
  ok "hyprland.lua lädt jetzt nur noch das Theme"

  # konkurrierende Leisten/Benachrichtigungsdienste: beenden und als Benutzerdienst maskieren
  local p u
  for p in waybar swaync dunst mako hyprpaper ags-v1; do
    if pgrep -x "$p" >/dev/null 2>&1; then pkill -x "$p" 2>/dev/null && ok "beendet: $p"; fi
  done
  for u in swaync dunst mako waybar; do
    if systemctl --user is-enabled "$u.service" 2>/dev/null | grep -E '^(enabled|static|alias)' >/dev/null; then
      systemctl --user mask "$u.service" >/dev/null 2>&1 && ok "Benutzerdienst $u maskiert (HUD übernimmt)" \
        && echo "  systemctl --user unmask $u.service" >> "$note"
    fi
  done
  ok "Rückweg notiert → $note"
}

# HUD sofort starten, wenn der Installer in einer laufenden Hyprland-Sitzung lief
# (theme.lua startet es nur bei hyprland.start, nicht bei hyprctl reload)
ubu_start_hud() {
  [ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ] || return 0
  command -v hyprctl >/dev/null && hyprctl reload >/dev/null 2>&1 || true
  if [ -x "$THEME/scripts/restart" ]; then
    "$THEME/scripts/restart" >/dev/null 2>&1 || true
    sleep 3
    pgrep -x gjs >/dev/null 2>&1 && ok "HUD gestartet" || warn "HUD startet beim nächsten Login"
  fi
}
