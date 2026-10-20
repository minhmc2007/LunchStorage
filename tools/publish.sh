#!/usr/bin/env bash
# publish out/x86_64 as pacman repo assets on a GitHub release
set -euo pipefail
cd "$(dirname "$0")/.."
TAG="${1:-repo}"
OUT="${OUT:-out/x86_64}"
[ -d "$OUT" ] || exit 0
mapfile -t assets < <(find "$OUT" -maxdepth 1 -type f \( -name '*.pkg.tar.zst' -o -name 'lunchstorage.*' \) -printf '%p\n')
[ "${#assets[@]}" -gt 0 ] || exit 0

gh release view "$TAG" >/dev/null 2>&1 || \
  gh release create "$TAG" --title "LunchStorage" --notes "pacman repository"

gh release upload "$TAG" "${assets[@]}" --clobber

tar -C "$(dirname "$OUT")" -czf "$(dirname "$OUT")/repo.tgz" "$(basename "$OUT")"
gh release upload "$TAG" "$(dirname "$OUT")/repo.tgz" --clobber

while read -r name; do
  [ "$name" = repo.tgz ] && continue
  [ -e "$OUT/$name" ] || gh release delete-asset "$TAG" "$name" -y
done < <(gh release view "$TAG" --json assets --jq '.assets[].name')
