#!/usr/bin/env bash
set -e -o pipefail
TAG=keys111
TOOLS=/mnt/d/本地项目-01/_k70port_extract
B=/root/k70/uefi/Build/vermeerPkg/DEBUG_CLANGPDB
cd /mnt/d/本地项目-01/_k70port_extract/wsl
rm -f "$B/FV/SILICIUM_UEFI.fd" "$B/FV/FVMAIN.Fv" "$B/FV/FVMAIN_COMPACT.Fv" "$B/FV/Guid.xref"

sed 's/keys109/keys111/g' build_keys109.sh > build_keys111.sh
chmod +x build_keys111.sh
# drop our (ineffective) APRIORI/dsc patch injection: GOP now comes from gates.py
python3 - <<'PY'
import pathlib
p = pathlib.Path('/mnt/d/本地项目-01/_k70port_extract/wsl/build_keys111.sh')
s = p.read_text(encoding='utf-8')
s2 = '\n'.join(('#' if 'patch_fb109.py' in ln else ln) for ln in s.splitlines())
p.write_text(s2 + '\n', encoding='utf-8')
print('disabled patch_fb109 injection ->', 'patch_fb109.py' not in s2.replace('#python3 /mnt/d/本地项目-01/_tools/patch_fb109.py',''))
PY
bash build_keys111.sh "$TAG"

echo "=== GUID bytes check (SimpleFbDxe DCFD1E6D-788D-4FFC-8E1B-CA2F75651A92) ==="
python3 - <<'PY'
import pathlib
m = pathlib.Path('/root/k70/uefi/Build/vermeerPkg/DEBUG_CLANGPDB/FV')
sfb = bytes.fromhex('6D1EFDDC8D78FC4F1B8ECA2F75651A92')
for name in ('FVMAIN.Fv','SILICIUM_UEFI.fd'):
    b=(m/name).read_bytes()
    print(f"{name}: size={len(b)} simplefb={b.count(sfb)}")
PY
sha256sum "$TOOLS/qemu-fw/SILICIUM_UEFI-$TAG.fd"
bash pack_keys.sh "$TOOLS/qemu-fw/SILICIUM_UEFI-$TAG.fd" "$TAG"