# LunchStorage

Pacman repo for LunchBox. PKGBUILDs pulled from AUR as git submodules (calamares is a plain file in `calamares/`), built by GitHub Actions into an unsigned repo consumed by the distro.

## Structure

- `pkgs/<pkg>/` - AUR submodule per package
- `calamares/PKGBUILD` - mirrored AUR PKGBUILD, plain file
- `manifest.json` - built state: `pkgver-pkgrel` per package, HEAD hash for -git packages
- `plan.json` / `packages-to-build.txt` - CI build list (generated)

## How it works

`tools/check.py` compares AUR state (RPC for versioned pkgs, `git ls-remote HEAD` for -git pkgs, PKGBUILD for calamares) against `manifest.json`. Changed or unbuilt packages go into the plan, `tools/build.sh` builds them, the result is pushed to the `repo` branch and attached to the `repo` release. Unchanged packages are skipped.

Update a submodule: `git submodule update --remote <name>`

## Consuming

Add `[lunchstorage]` with `Server = https://raw.githubusercontent.com/minhmc2007/LunchStorage/repo/x86_64`, unsigned. LunchBox bundles this at build time so installed systems stay offline-usable.
