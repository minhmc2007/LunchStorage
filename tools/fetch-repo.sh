#!/usr/bin/env bash
# download the previous release repo snapshot into out/
set -euo pipefail
cd "$(dirname "$0")/.."
TAG="${1:-repo}"
OUT="${OUT:-out/x86_64}"
mkdir -p "$(dirname "$OUT")"
if gh release view "$TAG" >/dev/null 2>&1; then
  tmp=$(mktemp -d)
  gh release download "$TAG" -p repo.tgz -D "$tmp" --clobber 2>/dev/null || true
  [ -f "$tmp/repo.tgz" ] && tar -C "$(dirname "$OUT")" -xzf "$tmp/repo.tgz"
  rm -rf "$tmp"
fi
