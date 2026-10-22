#!/bin/bash
# run151.sh -- build keys151 (keys149 lineage + Menu minimal DXE patch; PEI byte-identical)
#             and keys151b (same, but with the USB row removed from MemoryMapLib.c).
set -e
T=/mnt/d/本地项目-01/_tools
cd /mnt/d/本地项目-01/_k70port_extract/wsl

gen() {
  local tag="$1"
  sed "s/keys150/$tag/g" build_keys150.sh > "build_$tag.sh"
  sed "s/keys150/$tag/g" run_keys150.sh   > "run_$tag.sh"
  chmod +x "build_$tag.sh" "run_$tag.sh"
  echo "=== generated build_$tag.sh / run_$tag.sh ==="
}

echo "=== [0] preconditions ==="
ls -l build_keys150.sh run_keys150.sh
grep -c 'patch_nopmic138' build_keys150.sh || true
python3 "$T/patch_peimap151.py" check || true
python3 "$T/patch_peimap151.py" backup

# Menu patch: patch_usb150.py replaces Usb149 block with Usb150 block.
if grep -q 'Usb150LateDiag' /mnt/d/本地项目-01/_k70port_extract/port-drivers/VermeerMenuDxe/VermeerMenuDxe.c; then
  echo "=== Menu already carries Usb150 block (skip patch) ==="
else
  echo "=== apply patch_usb150.py ==="
  python3 "$T/patch_usb150.py"
fi

echo "=== [1] build keys151 (PEI untouched) ==="
gen keys151
bash run_keys151.sh 2>&1 | tail -10 || { echo "BUILD keys151 FAILED"; exit 1; }

echo "=== [2] remove USB row + build keys151b ==="
python3 "$T/patch_peimap151.py" remove
gen keys151b
bash run_keys151b.sh 2>&1 | tail -10 || { echo "BUILD keys151b FAILED"; python3 "$T/patch_peimap151.py" restore; exit 1; }
python3 "$T/patch_peimap151.py" restore

echo "=== [3] artifacts ==="
OUT=/mnt/d/本地项目-01/K70-UEFI-build
cp -f "$OUT/Mu-vermeer-keys151.img"    "$OUT/K70-keys151-NO-PEI-CHANGE.img"
cp -f "$OUT/Mu-vermeer-keys151b.img"   "$OUT/K70-keys151b-USBROW-REMOVED.img"
sha256sum /mnt/d/本地项目-01/_k70port_extract/qemu-fw/SILICIUM_UEFI-keys151.fd \
          /mnt/d/本地项目-01/_k70port_extract/qemu-fw/SILICIUM_UEFI-keys151b.fd \
          "$OUT/Mu-vermeer-keys151.img" "$OUT/K70-keys151-NO-PEI-CHANGE.img" \
          "$OUT/Mu-vermeer-keys151b.img" "$OUT/K70-keys151b-USBROW-REMOVED.img" || true
python3 "$T/patch_peimap151.py" check
echo "RUN151 DONE"
