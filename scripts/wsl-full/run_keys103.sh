#!/usr/bin/env bash
set -e -o pipefail
TAG=keys103
TOOLS=/mnt/d/本地项目-01/_k70port_extract
cd /mnt/d/本地项目-01/_k70port_extract/wsl
python3 /mnt/d/本地项目-01/_tools/patch_menu101.py
sed 's/keys14/keys103/g' build_keys14.sh > build_keys103.sh
chmod +x build_keys103.sh
python3 - <<'PY'
import pathlib
p = pathlib.Path('/mnt/d/本地项目-01/_k70port_extract/wsl/build_keys103.sh')
s = p.read_text(encoding='utf-8')
inject = '\npython3 /mnt/d/本地项目-01/_tools/patch_menu101.py  # re-apply after gates.py\n'
if 're-apply after gates.py' not in s:
    out = []
    for ln in s.splitlines(True):
        out.append(ln)
        if 'gates.py' in ln and 'keyprobe' in ln:
            out.append(inject)
    p.write_text(''.join(out), encoding='utf-8')
PY
bash build_keys103.sh "$TAG"
bash pack_keys.sh "$TOOLS/qemu-fw/SILICIUM_UEFI-$TAG.fd" "$TAG"