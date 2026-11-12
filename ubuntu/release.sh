#!/usr/bin/env bash
# Neues Release dieses Forks veröffentlichen, damit das HUD-Update-Banner (SUPER+SHIFT+Q) es meldet.
#
#   ubuntu/release.sh            -> VERSION um eins in der 4. Stelle erhöhen (2.3.26.1 -> 2.3.26.2)
#   ubuntu/release.sh 2.3.27.1   -> genau diese Version
#
# updater.sh fragt https://api.github.com/repos/<origin>/releases/latest und vergleicht den Tag mit VERSION.
# Ohne Release meldet das HUD nie ein Update. Schema: <Upstream-Version>.<Ubuntu-Release-Nr.>
# Voraussetzung: gh (angemeldet), sauberer Arbeitsbaum, auf master.
set -euo pipefail
cd "$(dirname "$0")/.."

command -v gh >/dev/null || { echo "✗ gh fehlt (sudo apt install gh && gh auth login)"; exit 1; }
[ "$(git symbolic-ref --short HEAD)" = master ] || { echo "✗ bitte auf master"; exit 1; }
[ -z "$(git status --porcelain --untracked-files=no)" ] || { echo "✗ uncommittete Änderungen – erst committen"; exit 1; }

old="$(tr -d '[:space:]' < VERSION)"
if [ -n "${1:-}" ]; then new="${1#v}"; else
  IFS=. read -r a b c d <<<"$old"
  new="$a.$b.$c.$(( ${d:-0} + 1 ))"
fi
tag="v$new"
git rev-parse -q --verify "refs/tags/$tag" >/dev/null && { echo "✗ Tag $tag existiert schon"; exit 1; }

prev="$(git describe --tags --abbrev=0 --match 'v*' 2>/dev/null || true)"
# erstes Release im Fork: ab dem letzten Versions-Commit des Originals („bump vX.Y.Z“)
base="${prev:-$(git log -1 --format=%H --grep='^bump v' 2>/dev/null || true)}"
notes="$(mktemp)"
{
  echo "## CyberArch-Shell für Ubuntu – $tag"
  echo
  if [ -n "$prev" ]; then echo "Änderungen seit $prev:"; else echo "Änderungen gegenüber dem Original (ARCANGEL0/CyberArch-Shell $old):"; fi
  echo
  git log --no-merges --format='- %s' ${base:+"$base"..HEAD} | grep -vE '^- (bump|release) ' || true
  echo
  echo "Aktualisieren: \`cd ~/CyberArch-Shell && ./updater.sh\` oder im HUD **SUPER+SHIFT+Q → UPDATE NOW**."
} > "$notes"

echo "▸ $old → $new"; cat "$notes"; echo
printf '%s\n' "$new" > VERSION
git add VERSION
git commit -q -m "release $tag"
git tag -a "$tag" -m "$tag"
git push -q origin master "$tag"
gh release create "$tag" --repo "$(git remote get-url origin | sed -E 's#^https://github.com/##; s#\.git$##')" \
  --title "$tag" --notes-file "$notes" --latest
rm -f "$notes"
echo "✓ $tag veröffentlicht – installierte Systeme mit älterer VERSION zeigen jetzt das Update-Banner."
