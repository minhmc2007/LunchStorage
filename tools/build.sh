#!/usr/bin/env bash
# builds plan from plan.json into out/x86_64 local pacman repo
set -euo pipefail
cd "$(dirname "$0")/.."
ROOT="$PWD"
OUT="${OUT:-out/x86_64}"
PKGS="${1:-$(python3 -c 'import json;print("\n".join(json.load(open("plan.json"))["packages"]))')}"
mkdir -p "$OUT"
useradd -m build 2>/dev/null || true
echo "build ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/10-build && chmod 440 /etc/sudoers.d/10-build

if (cd /tmp && runuser -u build -- test -x "$ROOT"); then
  BUILD_ROOT="$ROOT"
else
  BUILD_ROOT=$(mktemp -d /tmp/lunchstorage-build.XXXXXX)
  chmod 755 "$BUILD_ROOT"
  cp -a pkgs calamares "$BUILD_ROOT"/
  trap 'rm -rf "$BUILD_ROOT"' EXIT
fi
chown -R build:build "$BUILD_ROOT/pkgs" "$BUILD_ROOT/calamares" 2>/dev/null || true

meta() { bsdtar -xOf "$1" .PKGINFO | awk -F' = ' -v k="$2" '$1 == k { print $2; exit }'; }

install_pkgs() {
  [ "$#" -gt 0 ] || return 0
  if pacman -U --noconfirm --needed "$@"; then return; fi
  for f in "$@"; do
    provides=$(bsdtar -xOf "$f" .PKGINFO | sed -n 's/^provides = //p; s/[<>=].*//')
    conflicts=$(bsdtar -xOf "$f" .PKGINFO | sed -n 's/^conflict = //p; s/[<>=].*//')
    for c in $conflicts; do
      pacman -Qq "$c" >/dev/null 2>&1 || continue
      if ! grep -qx -- "$c" <<<"$provides"; then
        echo "== skip install: $c is not provided by $(meta "$f" pkgname)" >&2
        return 0
      fi
      echo "== replacing $c"
      pacman -Rdd --noconfirm "$c"
    done
  done
  pacman -U --noconfirm --needed "$@"
}

for pkg in $PKGS; do
  dir=pkgs/$pkg
  [ "$pkg" = calamares ] && dir=calamares
  build_dir="$BUILD_ROOT/$dir"
  skip=1
  have=0
  for f in "$build_dir"/*.pkg.tar.zst; do
    [ -e "$f" ] || continue
    have=1
    [ "$(pacman -Q "$(meta "$f" pkgname)" 2>/dev/null | cut -d' ' -f2)" = "$(meta "$f" pkgver)" ] || { skip=0; break; }
  done
  [ "$have" = 1 ] || skip=0
  if [ "$skip" = 1 ]; then
    echo "== skip $pkg (already built + installed)"
    cp "$build_dir"/*.pkg.tar.zst "$OUT/"
    [ "$build_dir" = "$dir" ] || cp "$build_dir"/*.pkg.tar.zst "$dir/"
    continue
  fi
  echo "== building $pkg"
  (cd "$build_dir" && runuser -u build -- env HOME=/home/build makepkg -C -f -s --skippgpcheck --nocheck --noconfirm --needed)
  mapfile -t listed < <(cd "$build_dir" && runuser -u build -- env HOME=/home/build makepkg --packagelist 2>/dev/null)
  built=()
  for f in "${listed[@]}"; do [ -f "$f" ] && built+=("$f"); done
  if [ "${#built[@]}" -eq 0 ]; then
    echo "== no package list for $pkg" >&2
    exit 1
  fi
  install_pkgs "${built[@]}"
  cp "${built[@]}" "$OUT/"
  [ "$build_dir" = "$dir" ] || cp "${built[@]}" "$dir/"
  for f in "$dir"/*.pkg.tar.zst; do
    [ -e "$f" ] || continue
    keep=0
    for b in "${built[@]}"; do
      [ "$(basename "$f")" = "$(basename "$b")" ] && { keep=1; break; }
    done
    [ "$keep" = 1 ] || rm -f "$f"
  done
done

if ls "$OUT"/*.pkg.tar.zst >/dev/null 2>&1; then
  repo-add --remove "$OUT/lunchstorage.db.tar.gz" "$OUT"/*.pkg.tar.zst
  rm -f "$OUT/lunchstorage.db" "$OUT/lunchstorage.files"
  cp "$OUT/lunchstorage.db.tar.gz" "$OUT/lunchstorage.db"
  if [ -f "$OUT/lunchstorage.files.tar.gz" ]; then
    cp "$OUT/lunchstorage.files.tar.gz" "$OUT/lunchstorage.files"
  fi
fi
