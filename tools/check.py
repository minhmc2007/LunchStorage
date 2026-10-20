#!/usr/bin/env python3
# compares upstream state against manifest.json, emits plan.json + updated manifest.json
import json, os, subprocess, sys, urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

def aur_records(names):
    if not names:
        return {}
    q = "&".join("arg[]=" + n for n in names)
    url = "https://aur.archlinux.org/rpc/v5/info?" + q
    res = json.load(urllib.request.urlopen(url))["results"]
    return {r["Name"]: r for r in res}

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
dirs = list(pkg_dirs())
records = aur_records([name for _, name in dirs if not name.endswith("-git")])

plan = []
for rel, name in dirs:
    if name.endswith("-git"):
        desired = aur_commit(name)
    elif name in records:
        desired = records[name]["Version"]
    else:
        pkgver = pkgrel = None
        for line in open(os.path.join(ROOT, rel, "PKGBUILD")):
            if line.startswith("pkgrel="):
                pkgrel = line.split("=", 1)[1].strip()
            elif line.startswith("pkgver="):
                pkgver = line.split("=", 1)[1].strip()
        desired = "%s-%s" % (pkgver, pkgrel) if (pkgver and pkgrel) else None
    if desired is None:
        print("# no state found for %s, skipping" % name, file=sys.stderr)
        continue
    if manifest.get(name) != desired:
        plan.append(name)
    manifest[name] = desired

def topo(p):
    if not p:
        return []
    raw, dep_names = {}, set()
    for n in p:
        r = records.get(n, {})
        vals = []
        for d in (r.get("Depends", []) or []) + (r.get("MakeDepends", []) or []):
            dn = d.split(">")[0].split("<")[0].split("=")[0]
            vals.append(dn)
            dep_names.add(dn)
        raw[n] = vals
    extra = aur_records([dn for dn in dep_names if dn not in p])

    def base_of(dn):
        if dn in p:
            return dn
        return extra.get(dn, {}).get("PackageBase")

    dmap = {}
    for n in p:
        edges = set()
        for dn in raw[n]:
            b = base_of(dn)
            if b and b in p and b != n:
                edges.add(b)
        dmap[n] = edges
    order, seen, vis = [], {}, set()

    def visit(n):
        if seen.get(n) or n in vis:
            return
        vis.add(n)
        for d in dmap.get(n, ()):
            visit(d)
        vis.discard(n)
        seen[n] = True
        order.append(n)

    for n in p:
        visit(n)
    return order

order = topo(plan)
json.dump(manifest, open(manifest_path, "w"), indent=1)
json.dump({"packages": order}, open(os.path.join(ROOT, "plan.json"), "w"), indent=1)
print("\n".join(order))
