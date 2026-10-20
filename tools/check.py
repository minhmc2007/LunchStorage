#!/usr/bin/env python3
# compares AUR state against manifest.json, emits plan.json and updated manifest.json
import json, os, subprocess, urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

def aur_info(bases):
    q = "&".join("arg[]=" + b for b in bases)
    res = json.load(urllib.request.urlopen("https://aur.archlinux.org/rpc/v5/info?" + q))["results"]
    return {r["PackageBase"]: r["Version"] for r in res}

def aur_commit(base):
    out = subprocess.run(["git", "ls-remote", "https://aur.archlinux.org/%s.git" % base, "HEAD"],
                         capture_output=True, text=True)
    return out.stdout.split()[0] if out.returncode == 0 else None

def pkg_dirs():
    for d in sorted(os.listdir(os.path.join(ROOT, "pkgs"))):
        p = os.path.join(ROOT, "pkgs", d)
        if os.path.isfile(os.path.join(p, "PKGBUILD")):
            yield "pkgs/" + d, d
    yield "calamares", "calamares"

manifest_path = os.path.join(ROOT, "manifest.json")
manifest = json.load(open(manifest_path)) if os.path.exists(manifest_path) else {}
plan = []

names, vcs = {}, []
for rel, name in pkg_dirs():
    if name.endswith("-git"):
        vcs.append(name)
    else:
        names.setdefault(name, None)

want = aur_info(names) if names else {}
for rel, name in pkg_dirs():
    if name.endswith("-git"):
        desired = aur_commit(name)
    elif name == "calamares":
        for line in open(os.path.join(ROOT, rel, "PKGBUILD")):
            if line.startswith("pkgrel="):
                pkgrel = line.split("=", 1)[1].strip()
                break
            if line.startswith("pkgver="):
                pkgver = line.split("=", 1)[1].strip()
        try: pkgver
        except NameError: continue
        desired = "%s-%s" % (pkgver, pkgrel)
    else:
        desired = want.get(name)
    if desired is None:
        print("# skip unknown %s" % name, file=__import__("sys").stderr)
        continue
    if manifest.get(name) != desired:
        plan.append(name)
    manifest[name] = desired

json.dump(manifest, open(manifest_path, "w"), indent=1)
json.dump({"packages": plan}, open(os.path.join(ROOT, "plan.json"), "w"), indent=1)
print("\n".join(plan))
