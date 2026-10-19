#!/usr/bin/env python3
"""Packages build/web (Godot Web export) for hosting where each file must stay small
(e.g. a private Claude Artifact, 15 MB per file): gzips the engine and game data, splits
them into parts and writes a launcher page from tools/web_shell.html.
Usage: tools/web_package.py [out_dir]   (default build/web_artifact)"""
import gzip, json, os, re, shutil, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "build", "web")
OUT = sys.argv[1] if len(sys.argv) > 1 else os.path.join(ROOT, "build", "web_artifact")
PART = 12 * 1024 * 1024

os.makedirs(OUT, exist_ok=True)
html = open(os.path.join(SRC, "index.html"), encoding="utf-8").read()
config = json.loads(re.search(r"const GODOT_CONFIG = (\{.*?\});", html).group(1))
config["args"] = []

parts = []
for name in ("index.wasm", "index.pck"):
    raw = open(os.path.join(SRC, name), "rb").read()
    gz = gzip.compress(raw, 9)
    spec = {"name": name, "size": len(raw), "parts": []}
    for i in range(0, len(gz), PART):
        fname = "%s.gz.%d.wasm" % (name, i // PART)   # .wasm: a type static hosts serve; the page reassembles + gunzips
        with open(os.path.join(OUT, fname), "wb") as f:
            f.write(gz[i:i + PART])
        spec["parts"].append({"file": fname, "size": len(gz[i:i + PART])})
    parts.append(spec)

for f in ("index.js", "index.audio.worklet.js", "index.audio.position.worklet.js"):
    shutil.copy(os.path.join(SRC, f), os.path.join(OUT, f))

total = sum(p["size"] for s in parts for p in s["parts"])
page = open(os.path.join(ROOT, "tools", "web_shell.html"), encoding="utf-8").read()
page = page.replace("__GODOT_CONFIG__", json.dumps(config)).replace("__PARTS__", json.dumps(parts))
page = page.replace("__DOWNLOAD_MB__", str(round(total / 1048576)))
open(os.path.join(OUT, "index.html"), "w", encoding="utf-8").write(page)
for s in parts:
    print(s["name"], s["size"], [(p["file"], p["size"]) for p in s["parts"]])
print("download total MB:", round(total / 1048576, 1))
