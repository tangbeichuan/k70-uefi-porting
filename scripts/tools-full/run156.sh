#!/usr/bin/env bash
# run156.sh -- build keys156 = keys154 lineage (PHYCFG clear + DCTL RUN_STOP=1,
# hardware-verified) + two [USB156] alive markers separated by gBS->Stall(3s).
# No new module, no PEI change, no QSCRATCH write.
set -e -o pipefail
TAG=keys156
TOOLS=/mnt/d/本地项目-01/_k70port_extract
B=/root/k70/uefi/Build/vermeerPkg/DEBUG_CLANGPDB
OUT=/mnt/d/本地项目-01/K70-UEFI-build
W=/mnt/d/本地项目-01/_k70port_extract/wsl

cd "$W"

# ---------------------------------------------------------------- build script
sed 's/keys154/keys156/g' build_keys154.sh > build_keys156.sh
# insert patch_usb156.py right after patch_usb154.py in the patch chain
python3 - "$W/build_keys156.sh" <<'PY'
import sys, pathlib
p = pathlib.Path(sys.argv[1])
s = p.read_text(encoding="utf-8")
old = "python3 /mnt/d/本地项目-01/_tools/patch_usb154.py"
assert s.count(old) == 1, f"patch_usb154.py count = {s.count(old)}"
s = s.replace(old, old + " && python3 /mnt/d/本地项目-01/_tools/patch_usb156.py", 1)
p.write_text(s, encoding="utf-8")
print("build_keys156.sh: patch chain += patch_usb156.py")
PY

echo "=== build_keys156.sh sanity ==="
echo "patch_usb156 count: $(grep -c 'patch_usb156.py' build_keys156.sh)  (want 1)"
echo "patch_nopmic138 count: $(grep -c 'patch_nopmic138.py' build_keys156.sh || true)  (want 0)"
echo "NO_HAL count: $(grep -c 'NO_HAL' build_keys156.sh || true)  (want 0)"
echo "UsbConfigDxe backup/restore trap count: $(grep -c 'UsbConfigDxe.patched.efi.bak143' build_keys156.sh || true)  (want 2)"
grep -n 'patch_usb15[456]' build_keys156.sh

if [ "${1:-}" = "probe" ]; then
  echo "=== PROBE MODE: stop before build ==="
  python3 /mnt/d/本地项目-01/_tools/patch_menu101.py || exit 1
  python3 /mnt/d/本地项目-01/_tools/patch_usb152.py
  python3 /mnt/d/本地项目-01/_tools/patch_usb154.py
  python3 /mnt/d/本地项目-01/_tools/patch_usb156.py
  M=/root/k70/uefi/Platforms/Xiaomi/vermeerPkg/Drivers/VermeerMenuDxe/VermeerMenuDxe.c
  echo "--- keys156 effective entry tail ---"
  grep -n 'MENU154\|USB156\|Stall (3000000)\|Usb154Run' "$M" | tail -12
  python3 /mnt/d/本地项目-01/_tools/patch_gcc155.py check && echo "GCC row present (unexpected)" || echo "GCC row absent (expected for keys156)"
  grep -n 'GCC' /root/k70/uefi/Platforms/Xiaomi/vermeerPkg/Library/MemoryMapLib/MemoryMapLib.c || echo "  OK: no GCC row in MemoryMapLib"
  exit 0
fi

# ---------------------------------------------------------------------- build
rm -f "$B/FV/SILICIUM_UEFI.fd" "$B/FV/FVMAIN.Fv" "$B/FV/FVMAIN_COMPACT.Fv" "$B/FV/Guid.xref"
bash build_keys156.sh "$TAG" 2>&1 | tee /tmp/$TAG-build.log | tail -6

# ----------------------------------------------------------------------- pack
bash pack_keys.sh "$TOOLS/qemu-fw/SILICIUM_UEFI-$TAG.fd" "$TAG" 2>&1 | tee /tmp/$TAG-pack.log | tail -4
cp -f "$OUT/Mu-vermeer-$TAG.img" "$OUT/Mu-vermeer-$TAG-fat.img"
cp -f "$OUT/Mu-vermeer-$TAG.img" "$OUT/K70-$TAG-ALIVE-CHECK.img"

echo "=== $TAG images ==="
sha256sum "$OUT/Mu-vermeer-$TAG.img" "$OUT/K70-$TAG-ALIVE-CHECK.img"
sha256sum "$TOOLS/qemu-fw/SILICIUM_UEFI-$TAG.fd"

# --------------------------------------------------------------- quick checks
cp "$B/FV/Guid.xref" "/mnt/d/本地项目-01/_tools/guid-$TAG.xref"
MENUD=$(find "$B" -name 'VermeerMenuDxe.efi' | head -1)
echo "--- menu EFI: $MENUD ($(stat -c%s "$MENUD") B) ---"
python3 - "$MENUD" <<'PY'
import sys, pathlib
raw = pathlib.Path(sys.argv[1]).read_bytes()
for m in ("MENU154", "USB154", "USB156", "Usb154Run", "100000"):
    print(f"  utf16 {m}: {raw.count(m.encode('utf-16-le'))}")
PY
echo "--- FV module list (menu/logdisk/dtb/usr) ---"
grep -iE 'VermeerMenuDxe|VermeerLogDiskDxe|VermeerDtbExtnDxe|UsbConfigDxe|UFSDxe' "/mnt/d/本地项目-01/_tools/guid-$TAG.xref" || true
echo "--- PEI sha (expect keys154's cfcfca5e... = keys149 map, no GCC row) ---"
python3 - <<'PY'
import struct, hashlib
buf = open("/mnt/d/本地项目-01/_k70port_extract/qemu-fw/SILICIUM_UEFI-keys156.fd", "rb").read()
def u16(b, o): return struct.unpack_from("<H", b, o)[0]
hdr = buf.find(b"_FVH", 0, 0x1000); base = hdr - 0x28
off = base + u16(buf, base + 0x30)
while off + 0x18 <= len(buf):
    ft = buf[off + 0x12]; sz = buf[off + 0x14] | (buf[off + 0x15] << 8) | (buf[off + 0x16] << 16)
    if sz < 0x18 or ft == 0xFF: break
    if ft == 0x03:
        body = buf[off + 0x18:off + sz]
        print("  SEC size", len(body), "sha", hashlib.sha256(body).hexdigest())
        for n in (b"GCC\x00", b"USB\x00"): print(f"  {n!r}: {body.count(n)}")
        break
    off = (off + sz + 7) & ~7
PY
