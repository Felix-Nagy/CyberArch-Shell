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
    dpkg-query -W -f '${Status}' "$d" 2>/dev/null | grep -q 'install ok installed' || return 1
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
    apt-get -o DPkg::Lock::Timeout=900 -o Dpkg::Options::=--force-confdef -o Dpkg::Options::=--force-confold "$@"
}

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
  if [ "${#debs[@]}" -gt 0 ]; then ubu_apt install -y "${debs[@]}" || rc=1; fi
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
  ubu_apt -o Acquire::http::Timeout=30 -o Acquire::https::Timeout=30 -o Acquire::Retries=3 update -qq || true
  if ! apt-cache policy hyprland 2>/dev/null | grep -q 'ppa.launchpadcontent.net/cppiber'; then
    fatal "Das Hyprland-PPA ist gerade nicht erreichbar (ppa.launchpadcontent.net)." \
      "Ohne PPA gibt es kein aktuelles Hyprland (≥ 0.56) für Ubuntu." \
      "Prüfen:  curl -I https://ppa.launchpadcontent.net/cppiber/hyprland/ubuntu/" \
      "Später einfach erneut starten – bereits erledigte Schritte werden übersprungen."
  fi
  step "Build- und Laufzeitpakete (ubuntu/packages.txt)"
  # shellcheck disable=SC2046
  ubu_apt install -y $(grep -v '^#' "$UBU_DIR/packages.txt") \
    || fatal "apt-get install fehlgeschlagen" "Log oben lesen, dann ./install.sh erneut starten"
  ok "Ubuntu-Pakete installiert"
  ubu_build astal astal-gjs ags quickshell mpvpaper awww nerdfonts || fatal "Quellcode-Build fehlgeschlagen" \
    "Log: ${CYBER_SRC:-$HOME/.cache/cyberarch-build}/build.log"
  ok "AGS/Astal/Quickshell/mpvpaper/awww bereit"
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
ubu_finish() {
  hdr "UBUNTU · Abschluss"
  if [ "$(readlink -f /etc/systemd/system/display-manager.service 2>/dev/null)" = "$(readlink -f /usr/lib/systemd/system/sddm.service 2>/dev/null)" ]; then
    # sddm.service prüft beim Start /etc/X11/default-display-manager (stünde nach GDM sonst auf gdm3)
    echo /usr/bin/sddm | command sudo tee /etc/X11/default-display-manager >/dev/null
    command sudo systemctl reset-failed sddm 2>/dev/null || true
    ok "SDDM startet beim nächsten Boot (default-display-manager → sddm)"
  fi
  if [ -d /var/lib/sddm ] && [ -f /usr/share/wayland-sessions/hyprland.desktop ]; then
    # beim ersten Login Hyprland + diesen Benutzer vorauswählen (sonst ggf. GNOME)
    printf '[Last]\nUser=%s\nSession=/usr/share/wayland-sessions/hyprland.desktop\n' "$(id -un)" \
      | command sudo tee /var/lib/sddm/state.conf >/dev/null
    command sudo chown sddm:sddm /var/lib/sddm/state.conf 2>/dev/null || true
    ok "SDDM wählt Hyprland + $(id -un) vor"
  fi
}
