#!/usr/bin/env bash
set +e
BFV=/root/k70/uefi/Build/vermeerPkg/DEBUG_CLANGPDB/FV
echo "=== FILE FREEFORM DTB in FVMAIN.inf ==="
grep -i "7E5B1C3A" "$BFV/FVMAIN.inf"
FFS=$(ls -d "$BFV"/Ffs/7E5B1C3A*/ 2>/dev/null | head -1)
echo "ffs dir: $FFS"
ls -l "$FFS" 2>/dev/null
echo "=== compare embedded DTB with source xbl_ufs.dtb ==="
python3 - <<'PY'
import glob, hashlib, pathlib
src = pathlib.Path('/root/k70/uefi/Platforms/Xiaomi/vermeerPkg/FdtBlob/xbl_ufs.dtb').read_bytes()
print('source dtb size', len(src), 'sha', hashlib.sha256(src).hexdigest())
pat = glob.glob('/root/k70/uefi/Build/vermeerPkg/DEBUG_CLANGPDB/FV/Ffs/7E5B1C3A*/*.ffs')
print('ffs:', pat)
for p in pat:
    d = pathlib.Path(p).read_bytes()
    print(' ffs size', len(d), 'sha', hashlib.sha256(d).hexdigest()[:16])
    print(' dtb found at', d.find(src), '-> payload identical:', d.find(src) >= 0)
PY
echo "=== provider slot strings in the DTBExtn FFS inside FV ==="
PFFS=$(ls -d "$BFV"/Ffs/5B21E7C4*/ 2>/dev/null | head -1)
for pat in "vermeer dtb-extn provider" "+0x28 count(" "+0x68 sizes(" "+0x70 names("; do
  echo -n "  [$pat] "; grep -ac "$pat" "$PFFS"/*.ffs 2>/dev/null
done
echo "=== FINAL artifact shas ==="
sha256sum /mnt/d/本地项目-01/_k70port_extract/qemu-fw/SILICIUM_UEFI-keys139.fd \
          /mnt/d/本地项目-01/_k70port_extract/qemu-fw/SILICIUM_UEFI-keys140.fd \
          /mnt/d/本地项目-01/K70-UEFI-build/K70-keys139-PROVIDER-SLOTS.img \
          /mnt/d/本地项目-01/K70-UEFI-build/K70-keys140-PMIC-RESTORED.img
ls -l /mnt/d/本地项目-01/K70-UEFI-build/K70-keys14*.img
