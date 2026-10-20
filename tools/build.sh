#!/usr/bin/env bash
# builds plan from plan.json into out/x86_64 local pacman repo
set -euo pipefail
cd "$(dirname "$0")/.."
OUT="${OUT:-out/x86_64}"
PKGS="${1:-$(python3 -c 'import json;print("\n".join(json.load(open("plan.json"))["packages"]))')}"
mkdir -p "$OUT"
useradd -m build 2>/dev/null || true
echo "build ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/10-build && chmod 440 /etc/sudoers.d/10-build
for pkg in $PKGS; do
  dir=pkgs/$pkg
  [ "$pkg" = calamares ] && dir=calamares
  echo "== building $pkg"
  (cd "$dir" && runuser -u build -- env HOME=/home/build makepkg -C -f -s --skippgpcheck --noconfirm --needed)
  pacman -U --noconfirm "$dir"/*.pkg.tar.zst
  cp "$dir"/*.pkg.tar.zst "$OUT/"
done
if ls "$OUT"/*.pkg.tar.zst >/dev/null 2>&1; then
  repo-add "$OUT/lunchstorage.db.tar.gz" "$OUT"/*.pkg.tar.zst
  ln -sf lunchstorage.db.tar.gz "$OUT/lunchstorage.db"
fi
