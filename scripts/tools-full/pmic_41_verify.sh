#!/usr/bin/env bash
set +e
TAG=$1
PKG=/root/k70/uefi/Platforms/Xiaomi/vermeerPkg
BFV=/root/k70/uefi/Build/vermeerPkg/DEBUG_CLANGPDB/FV
PORT=/mnt/d/本地项目-01/_k70port_extract/port-drivers/VermeerDtbExtnDxe
WSLSRC=$PKG/Drivers/VermeerDtbExtnDxe/VermeerDtbExtnDxe.c
FD=/mnt/d/本地项目-01/_k70port_extract/qemu-fw/SILICIUM_UEFI-$TAG.fd
IMG=/mnt/d/本地项目-01/K70-UEFI-build/Mu-vermeer-$TAG.img

echo "================ verification $TAG ================"
echo "--- 1) Guid.xref ---"
grep -i "VermeerDtbExtnDxe" "$BFV/FVMAIN.inf" "$BFV/Guid.xref" 2>/dev/null
echo "--- 2) provider banner string in FVMAIN.Fv / provider efi ---"
grep -ac "vermeer dtb-extn provider" "$BFV/FVMAIN.Fv" 2>/dev/null
PE=$(find /root/k70/uefi/Build/vermeerPkg/DEBUG_CLANGPDB/AARCH64 -name 'VermeerDtbExtnDxe.efi' 2>/dev/null | head -1)
echo "provider efi: $PE"
[ -n "$PE" ] && grep -ac "vermeer dtb-extn provider" "$PE"
echo "--- 2b) new slot debug strings in the built efi (proves new code is in) ---"
if [ -n "$PE" ]; then
  for pat in '+0x28 count(' '+0x68 sizes(' '+0x70 names(' '+0x90 size "' 'selftest vadc'; do
    c=$(grep -ac "$pat" "$PE")
    echo "  [$c] $pat"
  done
  echo -n "  provider efi sha256: "; sha256sum "$PE"
fi
echo "--- 3) source copies ---"
sha256sum "$WSLSRC" "$PORT/VermeerDtbExtnDxe.c"
echo "--- 4) images ---"
sha256sum "$FD" "$IMG"
echo "--- 5) slot cap sanity (A3, 512 in the *compiled* source copy) ---"
grep -c "A3, 512)" "$WSLSRC"
echo "--- 6) PmicDxeLa present in FV? ---"
grep -iE "PmicDxeLa|PmicDxe" "$BFV/Guid.xref" || echo "  (no PmicDxe in Guid.xref)"
grep -ic "PmicDxeLa" "$BFV/FVMAIN.inf" 2>/dev/null
