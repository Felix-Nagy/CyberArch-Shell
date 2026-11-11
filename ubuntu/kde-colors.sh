#!/usr/bin/env bash
# Dunkles KDE-Farbschema passend zum Kvantum-Theme "Daemon" (assets/gtk/DaemonKvantum/Daemon.kvconfig).
# Ohne ~/.config/kdeglobals nehmen KDE-Apps (Dolphin, Kate …) die helle Breeze-Palette -> dunkle Schrift
# auf Kvantums dunklem Hintergrund, kaum lesbar. Vorhandene, fremde kdeglobals wird gesichert.
set -euo pipefail

TEXT="90,238,220"      # #5aeedc
BG="7,13,26"           # #070d1a
ALT="17,30,41"         # #111e29
DIS="160,160,160"      # #a0a0a0
RED="255,45,61"        # #ff2d3d (Theme-Akzent)
VISITED="255,102,102"  # #ff6666

KG="${XDG_CONFIG_HOME:-$HOME/.config}/kdeglobals"
MARK="# cyberarch-ubuntu kde-colors"
if [ -f "$KG" ] && ! grep -qF "$MARK" "$KG"; then
  cp -f "$KG" "$KG.bak.$(date +%s)"
fi

group() { # group <Name> <Hintergrund> <Alt-Hintergrund>
  cat <<EOF
[Colors:$1]
BackgroundNormal=$2
BackgroundAlternate=$3
ForegroundNormal=$TEXT
ForegroundInactive=$DIS
ForegroundActive=$TEXT
ForegroundLink=$TEXT
ForegroundVisited=$VISITED
ForegroundNegative=$RED
ForegroundNeutral=255,214,31
ForegroundPositive=90,230,130
DecorationFocus=$TEXT
DecorationHover=$RED

EOF
}

{
  echo "$MARK"
  printf '[General]\nColorScheme=CyberArchDaemon\n\n'
  printf '[KDE]\nwidgetStyle=kvantum\n\n'
  group Window "$BG" "$ALT"
  group View "$BG" "$ALT"
  group Button "$BG" "$ALT"
  group Tooltip "$ALT" "$BG"
  group Complementary "$BG" "$ALT"
  group Header "$BG" "$ALT"
  # Auswahl: Cyan-Balken mit dunkler Schrift
  cat <<EOF
[Colors:Selection]
BackgroundNormal=$TEXT
BackgroundAlternate=$TEXT
ForegroundNormal=$BG
ForegroundInactive=$ALT
ForegroundActive=$BG
ForegroundLink=$BG
ForegroundVisited=$BG
ForegroundNegative=$RED
ForegroundNeutral=$BG
ForegroundPositive=$BG
DecorationFocus=$TEXT
DecorationHover=$RED

[ColorEffects:Disabled]
Color=$BG
ColorAmount=0
ColorEffect=0
ContrastAmount=0.65
ContrastEffect=1
IntensityAmount=0.1
IntensityEffect=2

[ColorEffects:Inactive]
ChangeSelectionColor=false
Enable=false
EOF
} > "$KG"
# KF6 löst ColorScheme=<Name> über color-schemes/<Name>.colors auf – fehlt die Datei, gilt wieder Breeze (hell)
CS="${XDG_DATA_HOME:-$HOME/.local/share}/color-schemes"
mkdir -p "$CS"
sed -e "s|^\[General\]$|[General]\nName=CyberArch Daemon|" -e "/^$MARK$/d" "$KG" > "$CS/CyberArchDaemon.colors"
# Außerhalb von Plasma nimmt KF6 das Schema pro App aus <app>rc [UiSettings] ColorScheme – sonst Breeze.
# Ohne diesen Eintrag bleibt Dolphins Schrift dunkelgrau auf dunklem Kvantum-Hintergrund.
for app in dolphin kate okular gwenview ark konsole; do
  rc="${XDG_CONFIG_HOME:-$HOME/.config}/${app}rc"
  touch "$rc"
  if grep -q '^\[UiSettings\]' "$rc"; then
    sed -i '/^\[UiSettings\]/,/^\[/{/^ColorScheme=/d}' "$rc"
    sed -i 's/^\[UiSettings\]$/[UiSettings]\nColorScheme=CyberArchDaemon/' "$rc"
  else
    printf '\n[UiSettings]\nColorScheme=CyberArchDaemon\n' >> "$rc"
  fi
done
echo "kdeglobals → $KG, Farbschema → $CS/CyberArchDaemon.colors, KDE-Apps → CyberArchDaemon"
