#!/usr/bin/env bash
# Baut die Komponenten von CyberArch-Shell, die es in Ubuntu 26.04 nicht als Paket gibt.
#   ./build-deps.sh            -> alles
#   ./build-deps.sh astal ags  -> nur ausgewählte Schritte
# Schritte: astal astal-gjs ags quickshell mpvpaper awww
set -euo pipefail

SRC="${CYBER_SRC:-$HOME/.cache/cyberarch-build}"
mkdir -p "$SRC"
JOBS="$(nproc)"

# Versionen (bewusst gepinnt, damit der Build reproduzierbar bleibt)
ASTAL_REF="${ASTAL_REF:-main}"
ASTAL_GJS_REF="7b4d376"          # letzter Astal-Commit mit lang/gjs (wurde in 9b67eb5 entfernt)
AGS_REF="v3.1.2"                 # entspricht aylurs-gtk-shell im AUR
QUICKSHELL_REF="${QUICKSHELL_REF:-}"   # leer = neuester Release-Tag
MPVPAPER_REF="${MPVPAPER_REF:-}"
AWWW_REF="${AWWW_REF:-}"

log() { printf '\033[38;2;119;226;242m▸\033[0m %s\n' "$*"; }

clone() { # clone <url> <dir> [ref]
  local url="$1" dir="$SRC/$2" ref="${3:-}"
  # mit Wiederholung: Codeberg/GitHub liefern gelegentlich 5xx (beim Test: 504 von codeberg.org)
  local n
  for n in 1 2 3 4 5; do
    if [ ! -d "$dir/.git" ]; then
      rm -rf "$dir"; git clone -q "$url" "$dir" && break
    else
      git -C "$dir" fetch -q --tags origin && break
    fi
    [ "$n" = 5 ] && { echo "✗ $url nicht erreichbar (5 Versuche)" >&2; return 1; }
    echo "  ⚠ $url nicht erreichbar – neuer Versuch in $((n * 15)) s" >&2
    sleep $((n * 15))
  done
  if [ -n "$ref" ]; then git -C "$dir" checkout -q "$ref"; else
    git -C "$dir" checkout -q "origin/HEAD" 2>/dev/null || git -C "$dir" pull -q
  fi
}

latest_tag() { git -C "$SRC/$1" tag --sort=-v:refname | grep -E '^v?[0-9]' | head -1; }

BUILDLOG="$SRC/build.log"
run_logged() { # führt Befehl aus, zeigt bei Fehler die letzten Logzeilen
  if ! "$@" >>"$BUILDLOG" 2>&1; then
    printf '\033[38;2;255;45;61m✗\033[0m fehlgeschlagen: %s\n' "$*" >&2
    grep -iE 'error|not found|dependency' "$BUILDLOG" | tail -15 >&2
    exit 1
  fi
}

meson_install() { # meson_install <dir>
  : >"$BUILDLOG"
  cd "$1"; rm -rf build
  run_logged meson setup build --prefix /usr --buildtype release
  run_logged meson compile -C build -j "$JOBS"
  run_logged sudo meson install -C build
  cd - >/dev/null
}

build_astal() {
  log "astal libs ($ASTAL_REF)"
  clone https://github.com/Aylur/astal astal "$ASTAL_REF"
  local l
  # Pflicht: was core.ts / die Module importieren (+ astal4 für ags selbst)
  for l in quarrel wayland-glib astal/io astal/gtk3 astal/gtk4 notifd wireplumber mpris; do
    log "  lib/$l"
    meson_install "$SRC/astal/lib/$l"
  done
  # Optional: nützlich für eigene Erweiterungen, Fehler brechen nicht ab
  for l in apps battery bluetooth network powerprofiles hyprland tray; do
    log "  lib/$l (optional)"
    ( meson_install "$SRC/astal/lib/$l" ) || printf '  ⚠ lib/%s übersprungen\n' "$l"
  done
  sudo ldconfig
}

build_astal_gjs() {
  log "astal gjs package ($ASTAL_GJS_REF) → /usr/share/astal/gjs"
  clone https://github.com/Aylur/astal astal-gjs "$ASTAL_GJS_REF"
  meson_install "$SRC/astal-gjs/lang/gjs"
}

build_ags() {
  log "ags ($AGS_REF)"
  clone https://github.com/Aylur/ags ags "$AGS_REF"
  ( cd "$SRC/ags" && npm install --silent --no-audit --no-fund )
  meson_install "$SRC/ags"
}

build_quickshell() {
  clone https://github.com/quickshell-mirror/quickshell quickshell
  local ref="${QUICKSHELL_REF:-$(latest_tag quickshell)}"
  git -C "$SRC/quickshell" checkout -q "$ref"
  log "quickshell ($ref)"
  : >"$BUILDLOG"; cd "$SRC/quickshell"; rm -rf build
  run_logged cmake -GNinja -B build -DCMAKE_BUILD_TYPE=RelWithDebInfo \
      -DCMAKE_INSTALL_PREFIX=/usr -DDISTRIBUTOR="CyberArch-Ubuntu" -DCRASH_HANDLER=OFF -DI3=OFF -DX11=OFF
  run_logged cmake --build build -j "$JOBS"
  run_logged sudo cmake --install build
  cd - >/dev/null
}

build_mpvpaper() {
  clone https://github.com/GhostNaN/mpvpaper mpvpaper
  local ref="${MPVPAPER_REF:-$(latest_tag mpvpaper)}"
  git -C "$SRC/mpvpaper" checkout -q "$ref"
  log "mpvpaper ($ref)"
  meson_install "$SRC/mpvpaper"
}

build_awww() {
  clone https://codeberg.org/LGFae/awww awww
  local ref="${AWWW_REF:-$(latest_tag awww)}"
  [ -n "$ref" ] && git -C "$SRC/awww" checkout -q "$ref"
  log "awww (${ref:-HEAD})"
  : >"$BUILDLOG"; cd "$SRC/awww"
  run_logged cargo build --release
  run_logged sudo install -m 755 target/release/awww target/release/awww-daemon /usr/bin/
  cd - >/dev/null
}

build_nerdfonts() { # Arch: ttf-firacode-nerd, ttf-nerd-fonts-symbols(-mono)
  log "Nerd Fonts (FiraCode, Symbols Only)"
  local dst=/usr/local/share/fonts/nerd tmp f
  tmp="$(mktemp -d)"
  for f in FiraCode NerdFontsSymbolsOnly; do
    curl -fsSL --retry 5 --retry-delay 10 --retry-all-errors -o "$tmp/$f.tar.xz" "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/$f.tar.xz"
    sudo install -d "$dst/$f"
    sudo tar -xJf "$tmp/$f.tar.xz" -C "$dst/$f" --wildcards '*.ttf'
  done
  rm -rf "$tmp"
  sudo fc-cache -f "$dst" >/dev/null
}

STEPS=("$@")
[ "${#STEPS[@]}" -eq 0 ] && STEPS=(astal astal-gjs ags quickshell mpvpaper awww nerdfonts)
for s in "${STEPS[@]}"; do
  case "$s" in
    astal) build_astal ;;
    astal-gjs) build_astal_gjs ;;
    ags) build_ags ;;
    quickshell) build_quickshell ;;
    mpvpaper) build_mpvpaper ;;
    awww) build_awww ;;
    nerdfonts) build_nerdfonts ;;
    *) echo "unbekannter Schritt: $s" >&2; exit 1 ;;
  esac
done
log "fertig: ${STEPS[*]}"
