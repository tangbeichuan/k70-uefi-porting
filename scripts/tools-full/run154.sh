#!/usr/bin/env bash
# run154.sh -- build keys154 = keys152 + Menu USB154 (GCC-read crash fixed,
# PHYCFG/DCTL RUN sequence, no QSCRATCH writes, no CpuDeadLoop).
set -e -o pipefail
TOOLS=/mnt/d/本地项目-01/_k70port_extract
OUT=/mnt/d/本地项目-01/K70-UEFI-build
B=/root/k70/uefi/Build/vermeerPkg/DEBUG_CLANGPDB
WSLD=/mnt/d/本地项目-01/_k70port_extract/wsl
cd "$WSLD"

# ---- derive keys154 lineage from keys152 -----------------------------------
sed 's/keys152/keys154/g' build_keys152.sh > build_keys154.sh
python3 - <<'PY'
import pathlib
p = pathlib.Path("build_keys154.sh")
s = p.read_text()
needle = "patch_usb152.py"
ins = "patch_usb152.py && python3 /mnt/d/本地项目-01/_tools/patch_usb154.py"
if "patch_usb154.py" not in s:
    if needle not in s:
        raise SystemExit("FATAL: patch_usb152.py not in build chain")
    s = s.replace(needle, ins, 1)
    p.write_text(s)
print("chain:", [l for l in s.splitlines() if "patch_usb154" in l][:1])
PY
grep -q 'patch_usb154.py' build_keys154.sh || { echo "FATAL: patch_usb154 not in build chain"; exit 1; }

# ---- build -----------------------------------------------------------------
rm -f "$B/FV/SILICIUM_UEFI.fd" "$B/FV/FVMAIN.Fv" "$B/FV/FVMAIN_COMPACT.Fv" "$B/FV/Guid.xref"
bash build_keys154.sh keys154 2>&1 | tee /tmp/keys154-build.log | tail -8
grep -q "PROGRESS - Success" /tmp/keys154-build.log || { echo "FATAL: build did not finish"; exit 1; }

# ---- snapshots / pack ------------------------------------------------------
cp -f "$B/FV/Guid.xref" /mnt/d/本地项目-01/_tools/guid-keys154.xref
bash pack_keys.sh "$TOOLS/qemu-fw/SILICIUM_UEFI-keys154.fd" keys154 2>&1 | tee /tmp/keys154-pack.log | tail -4
cp -f "$OUT/Mu-vermeer-keys154.img" "$OUT/K70-keys154-USB-RUN.img"

echo "=== keys154 artifacts ==="
sha256sum "$TOOLS/qemu-fw/SILICIUM_UEFI-keys154.fd" \
          "$OUT/Mu-vermeer-keys154.img" \
          "$OUT/K70-keys154-USB-RUN.img" 

echo "=== Menu EFI markers ==="
MENUD=$(find "$B" -name 'VermeerMenuDxe.efi' | head -1)
echo "menu: $MENUD  size=$(stat -c%s "$MENUD")"
strings -el "$MENUD" | grep -E 'MENU154|USB154' | head -10
echo "=== Menu disasm: any GCC read left? (expect none) ==="
llvm-objdump -d "$MENUD" > /tmp/menu154.asm
grep -n 'mov\s*w8, #0xf004' /tmp/menu154.asm || echo "  OK: no GCC_GDSCR address materialization"
echo "=== keys154 image structure ==="
python3 /mnt/d/本地项目-01/_tools/k152_tail3.py "$OUT/Mu-vermeer-keys154.img" 2>/dev/null | tail -20 || true
