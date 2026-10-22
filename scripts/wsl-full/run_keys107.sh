#!/usr/bin/env bash
set -e -o pipefail
TAG=keys107
TOOLS=/mnt/d/本地项目-01/_k70port_extract
cd /mnt/d/本地项目-01/_k70port_extract/wsl
sed 's/keys106/keys107/g' build_keys106.sh > build_keys107.sh
chmod +x build_keys107.sh
python3 - <<'PY'
import pathlib
p = pathlib.Path('/mnt/d/本地项目-01/_k70port_extract/wsl/build_keys107.sh')
s = p.read_text(encoding='utf-8')
inject = 'python3 /mnt/d/本地项目-01/_tools/patch_fb107.py  # GOP (SimpleFbDxe)\n'
if 'patch_fb107.py' not in s:
    out=[]
    for ln in s.splitlines(True):
        out.append(ln)
        if 'patch_menu101.py' in ln and 're-apply' in ln:
            out.append(inject)
    p.write_text(''.join(out), encoding='utf-8')
    print('injected patch_fb107')
PY
bash build_keys107.sh "$TAG"
bash pack_keys.sh "$TOOLS/qemu-fw/SILICIUM_UEFI-$TAG.fd" "$TAG"
echo "=== FV check ==="
python3 /mnt/d/本地项目-01/_tools/count_guid.py /root/k70/uefi/Build/vermeerPkg/DEBUG_CLANGPDB/FV/Guid.xref DCFD1E6D 4F7A1C2E 5C1E9A73 2>/dev/null || true