#!/usr/bin/env bash
# run157.sh -- build keys157:
#   * DWC3 device-mode bring-up moved into VermeerDtbExtnDxe (APRIORI pos 4,
#     before UsbConfig/UsbInit/UsbfnDwc3/UsbDevice/UsbMsd) -- hardware-verified
#     keys154 write sequence (PHYCFG clear + DCTL.RUN_STOP=1 + poll hlt22);
#   * Menu is a READ-ONLY resident monitor: [USB157] reads only, 100 ms key
#     polling loop so the device stays enumerated (no return to BDS, no
#     CpuDeadLoop), no GCC access (unmapped in DXE).
# lineage: keys156 (keys154 + alive markers) -> keys157.
set -e -o pipefail
TAG=keys157
TOOLS=/mnt/d/本地项目-01/_k70port_extract
B=/root/k70/uefi/Build/vermeerPkg/DEBUG_CLANGPDB
OUT=/mnt/d/本地项目-01/K70-UEFI-build
W=/mnt/d/本地项目-01/_k70port_extract/wsl

cd "$W"

# ---------------------------------------------------------------- build script
sed 's/keys156/keys157/g' build_keys156.sh > build_keys157.sh
python3 - "$W/build_keys157.sh" <<'PY'
import sys, pathlib
p = pathlib.Path(sys.argv[1])
s = p.read_text(encoding="utf-8")
old = ("python3 /mnt/d/本地项目-01/_tools/patch_usb152.py && "
       "python3 /mnt/d/本地项目-01/_tools/patch_usb154.py && "
       "python3 /mnt/d/本地项目-01/_tools/patch_usb156.py")
assert s.count(old) == 1, f"keys154/156 menu chain count = {s.count(old)}"
s = s.replace(old, "python3 /mnt/d/本地项目-01/_tools/patch_usb157.py", 1)
p.write_text(s, encoding="utf-8")
print("build_keys157.sh: menu chain -> patch_usb157.py")
PY

echo "=== build_keys157.sh sanity ==="
echo "patch_usb157 count: $(grep -c 'patch_usb157.py' build_keys157.sh)  (want 1)"
echo "patch_usb15[246] count: $(grep -cE 'patch_usb15[246]\.py' build_keys157.sh || true)  (want 0)"
echo "patch_nopmic138 count: $(grep -c 'patch_nopmic138.py' build_keys157.sh || true)  (want 0)"
echo "NO_HAL count: $(grep -c 'NO_HAL' build_keys157.sh || true)  (want 0)"
echo "UsbConfigDxe backup/restore trap count: $(grep -c 'UsbConfigDxe.patched.efi.bak143' build_keys157.sh || true)  (want 2)"
grep -n 'patch_usb157\|patch_extn136' build_keys157.sh

if [ "${1:-}" = "probe" ]; then
  echo "=== PROBE MODE: stop before build ==="
  python3 /mnt/d/本地项目-01/_tools/patch_menu101.py || exit 1
  python3 /mnt/d/本地项目-01/_tools/patch_usb157.py
  M=/root/k70/uefi/Platforms/Xiaomi/vermeerPkg/Drivers/VermeerMenuDxe/VermeerMenuDxe.c
  echo "--- keys157 effective Menu tail ---"
  grep -n 'MENU157\|USB157\|ReadKeyStroke\|CpuDeadLoop' "$M" | tail -12
  echo "--- keys157 Menu must not write USB/GCC ---"
  grep -n 'Usb150Wr\|0x0010F004\|Usb150Dump' "$M" || echo "  OK: no writes / no GCC access"
  echo "--- DtbExtn source early USB157 block ---"
  D=/root/k70/uefi/Platforms/Xiaomi/vermeerPkg/Drivers/VermeerDtbExtnDxe/VermeerDtbExtnDxe.c
  grep -n 'USB157' "$D" | head -8
  ls -l "$D"
  python3 /mnt/d/本地项目-01/_tools/patch_gcc155.py check && echo "GCC row present (unexpected)" || echo "GCC row absent (expected)"
  exit 0
fi

# ---------------------------------------------------------------------- build
rm -f "$B/FV/SILICIUM_UEFI.fd" "$B/FV/FVMAIN.Fv" "$B/FV/FVMAIN_COMPACT.Fv" "$B/FV/Guid.xref"
bash build_keys157.sh "$TAG" 2>&1 | tee /tmp/$TAG-build.log | tail -8

# ----------------------------------------------------------------------- pack
bash pack_keys.sh "$TOOLS/qemu-fw/SILICIUM_UEFI-$TAG.fd" "$TAG" 2>&1 | tee /tmp/$TAG-pack.log | tail -4
cp -f "$OUT/Mu-vermeer-$TAG.img" "$OUT/Mu-vermeer-$TAG-fat.img"
cp -f "$OUT/Mu-vermeer-$TAG.img" "$OUT/K70-$TAG-EARLY-USB-RUN.img"

echo "=== $TAG images ==="
sha256sum "$OUT/Mu-vermeer-$TAG.img" "$OUT/K70-$TAG-EARLY-USB-RUN.img"
sha256sum "$TOOLS/qemu-fw/SILICIUM_UEFI-$TAG.fd"

# --------------------------------------------------------------- quick checks
cp "$B/FV/Guid.xref" "/mnt/d/本地项目-01/_tools/guid-$TAG.xref"
MENUD=$(find "$B" -name 'VermeerMenuDxe.efi' | head -1)
DTBEFI=$(find "$B" -name 'VermeerDtbExtnDxe.efi' | head -1)
echo "--- menu EFI: $MENUD ($(stat -c%s "$MENUD") B) ---"
python3 - "$MENUD" "$DTBEFI" <<'PY'
import sys, pathlib
for path, marks in ((sys.argv[1], ("MENU157", "USB157", "UI157", "RunMenu")),
                    (sys.argv[2], ("USB157", "[VBUS]", "selftest vadc"))):
    raw = pathlib.Path(path).read_bytes()
    print(f"  {path} ({len(raw)} B)")
    for m in marks:
        print(f"    ascii {m}: {raw.count(m.encode())}  utf16 {m}: {raw.count(m.encode('utf-16-le'))}")
PY
echo "--- FV module list (menu/logdisk/dtb/usr/usb) ---"
grep -iE 'VermeerMenuDxe|VermeerLogDiskDxe|VermeerDtbExtnDxe|UsbConfigDxe|UFSDxe' "/mnt/d/本地项目-01/_tools/guid-$TAG.xref" || true
echo "--- PEI sha (expect keys149-152's cfcfca5e... no GCC row) ---"
python3 - <<'PY'
import struct, hashlib
buf = open("/mnt/d/本地项目-01/_k70port_extract/qemu-fw/SILICIUM_UEFI-keys157.fd", "rb").read()
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
