#!/usr/bin/env bash
set -e -o pipefail
TAG=keys109
TOOLS=/mnt/d/本地项目-01/_k70port_extract
B=/root/k70/uefi/Build/vermeerPkg/DEBUG_CLANGPDB
cd /mnt/d/本地项目-01/_k70port_extract/wsl

rm -f "$B/FV/SILICIUM_UEFI.fd" "$B/FV/FVMAIN.Fv" "$B/FV/FVMAIN_COMPACT.Fv" "$B/FV/Guid.xref"

sed 's/keys108/keys109/g' build_keys108.sh > build_keys109.sh
chmod +x build_keys109.sh
# swap the injected patch
python3 - <<'PY'
import pathlib
p = pathlib.Path('/mnt/d/本地项目-01/_k70port_extract/wsl/build_keys109.sh')
s = p.read_text(encoding='utf-8')
s = s.replace('patch_fb107.py', 'patch_fb109.py')
p.write_text(s, encoding='utf-8')
print('build_keys109: patch swapped to patch_fb109.py ->', 'patch_fb109.py' in s)
PY
bash build_keys109.sh "$TAG"

echo "=== GUID bytes check ==="
python3 - <<'PY'
import pathlib
m = pathlib.Path('/root/k70/uefi/Build/vermeerPkg/DEBUG_CLANGPDB/FV')
sfb = bytes.fromhex('6D1EFDDC8D78FC4F1B8ECA2F75651A92')
for name in ('FVMAIN.Fv','SILICIUM_UEFI.fd'):
    b=(m/name).read_bytes()
    print(f"{name}: size={len(b)} simplefb={b.count(sfb)}")
PY
bash pack_keys.sh "$TOOLS/qemu-fw/SILICIUM_UEFI-$TAG.fd" "$TAG"