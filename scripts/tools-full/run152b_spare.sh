#!/usr/bin/env bash
# run152b_spare.sh -- build keys152b (spare): prints-only Menu, NO USB dump/writes.
# Purpose: if keys154 still faults inside Menu, keys152b proves whether the DWC3
# register dump itself (rather than any write) is what breaks.
set -e -o pipefail
TOOLS=/mnt/d/本地项目-01/_k70port_extract
OUT=/mnt/d/本地项目-01/K70-UEFI-build
B=/root/k70/uefi/Build/vermeerPkg/DEBUG_CLANGPDB
WSLD=/mnt/d/本地项目-01/_k70port_extract/wsl
cd "$WSLD"

sed 's/keys152/keys152b/g' build_keys152.sh > build_keys152b.sh
# the tag sed does NOT touch patch_usb152.py (it contains "usb152", not "keys152")
python3 - <<'PY'
import pathlib
p = pathlib.Path("build_keys152b.sh")
s = p.read_text()
if "patch_usb152b.py" not in s:
    if "patch_usb152.py" not in s:
        raise SystemExit("FATAL: patch_usb152.py not in build chain")
    s = s.replace("/patch_usb152.py", "/patch_usb152b.py", 1)
    p.write_text(s)
print("chain:", [l for l in s.splitlines() if "patch_usb152b" in l][:1])
PY
grep -q 'patch_usb152b.py' build_keys152b.sh || { echo "FATAL: patch_usb152b not in build chain"; exit 1; }

rm -f "$B/FV/SILICIUM_UEFI.fd" "$B/FV/FVMAIN.Fv" "$B/FV/FVMAIN_COMPACT.Fv" "$B/FV/Guid.xref"
bash build_keys152b.sh keys152b 2>&1 | tee /tmp/keys152b-build.log | tail -8
grep -q "PROGRESS - Success" /tmp/keys152b-build.log || { echo "FATAL: build did not finish"; exit 1; }

cp -f "$B/FV/Guid.xref" /mnt/d/本地项目-01/_tools/guid-keys152b.xref
bash pack_keys.sh "$TOOLS/qemu-fw/SILICIUM_UEFI-keys152b.fd" keys152b 2>&1 | tee /tmp/keys152b-pack.log | tail -4
cp -f "$OUT/Mu-vermeer-keys152b.img" "$OUT/K70-keys152b-NO-DUMP.img"

echo "=== keys152b artifacts ==="
sha256sum "$TOOLS/qemu-fw/SILICIUM_UEFI-keys152b.fd" \
          "$OUT/Mu-vermeer-keys152b.img" \
          "$OUT/K70-keys152b-NO-DUMP.img"

MENUD=$(find "$B" -name 'VermeerMenuDxe.efi' | head -1)
echo "menu: $MENUD  size=$(stat -c%s "$MENUD")"
strings -el "$MENUD" | grep -E 'MENU152B|UI152B' | head -10
