#!/usr/bin/env bash
# vermeer ships its own Binaries/vermeer, so the Device-Binaries submodule is not required.
set -e
DB=/root/k70/uefi/Platforms/Xiaomi/vermeerPkg/DeviceBuild.py
python3 - "$DB" <<'PY'
import sys
p = sys.argv[1]
src = open(p, encoding="utf-8").read()
old = '            RequiredSubmodule ("Binaries", True),\n'
new = '            # RequiredSubmodule ("Binaries", True),  # vermeer ships Binaries/vermeer itself\n'
if old in src:
    open(p, "w", encoding="utf-8", newline="\n").write(src.replace(old, new))
    print("patched: Binaries submodule requirement removed")
elif "ships Binaries/vermeer" in src:
    print("already patched")
else:
    print("PATTERN NOT FOUND - inspect manually")
PY
grep -n 'RequiredSubmodule' "$DB"
