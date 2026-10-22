#!/usr/bin/env bash
# run161.sh -- build keys161 / keys161b from the keys160 lineage.
#
#   TAG=keys161  SUF=161  COPY=NO-SOFTRESET   (default)
#   TAG=keys161b SUF=161b COPY=MINIMAL-WRITE
#
# keys161 : EP0 gadget with NO DCTL.CSFTRST, PHYCFG fully cleared + 20 ms,
#           DCTL.CSFTRST forced 0 without pulsing, RUN_STOP off/on retried 3x if
#           halted, event buffer GEVNTSIZ=0x1000 (bit31=0), DEVTEN=0x7, EP0/TRB
#           logic unchanged from keys160, probes kept and widened.
# keys161b: minimal-write保险版: PHYCFG clears SUSPHY/ENBLSLPM only and DCTL is
#           untouched when the controller already reports run=1/hlt22=0.
set -e -o pipefail
TAG=${TAG:-keys161}
SUF=${SUF:-161}
COPY=${COPY:-NO-SOFTRESET}
TOOLS=/mnt/d/本地项目-01/_k70port_extract
B=/root/k70/uefi/Build/vermeerPkg/DEBUG_CLANGPDB
OUT=/mnt/d/本地项目-01/K70-UEFI-build
W=/mnt/d/本地项目-01/_k70port_extract/wsl
MENU=/root/k70/uefi/Platforms/Xiaomi/vermeerPkg/Drivers/VermeerMenuDxe/VermeerMenuDxe.c

cd "$W"

echo "=== $TAG (menu patch patch_usb$SUF.py) ==="
sed "s/keys160/$TAG/g" build_keys160.sh > "build_$TAG.sh"
python3 - "$W/build_$TAG.sh" "$SUF" <<'PY'
import sys, pathlib
p = pathlib.Path(sys.argv[1]); suf = sys.argv[2]
s = p.read_text(encoding="utf-8")
old = "python3 /mnt/d/本地项目-01/_tools/patch_usb160.py"
assert s.count(old) == 1, f"patch_usb160 count = {s.count(old)}"
s = s.replace(old, f"python3 /mnt/d/本地项目-01/_tools/patch_usb{suf}.py", 1)
p.write_text(s, encoding="utf-8")
print(f"{p.name}: menu patch -> patch_usb{suf}.py")
PY

echo "=== build_$TAG.sh sanity ==="
echo "patch_usb$SUF count: $(grep -c "patch_usb$SUF.py" "build_$TAG.sh")  (want 1)"
echo "patch_usb160 count: $(grep -c 'patch_usb160.py' "build_$TAG.sh" || true)  (want 0)"
echo "patch_nopmic138 count: $(grep -c 'patch_nopmic138.py' "build_$TAG.sh" || true)  (want 0)"
echo "NO_HAL count: $(grep -c 'NO_HAL' "build_$TAG.sh" || true)  (want 0)"
echo "UsbConfigDxe backup/restore trap count: $(grep -c 'UsbConfigDxe.patched.efi.bak143' "build_$TAG.sh" || true)  (want 2)"

if [ "${1:-}" = "probe" ]; then
  echo "=== PROBE MODE: stop before build ==="
  python3 /mnt/d/本地项目-01/_tools/patch_menu101.py || exit 1
  python3 "/mnt/d/本地项目-01/_tools/patch_usb$SUF.py" || exit 1
  echo "--- keys: symbols ---"
  grep -n "MENU$SUF\|USB$SUF\|Usb$SUF"$'\x4' "$MENU" 2>/dev/null | head -5 || true
  grep -n "MENU$SUF\|USB$SUF" "$MENU" | head -12
  echo "--- must not touch GCC / old diag ---"
  grep -n '0x0010F004\|0x0010F000\|Usb150Wr\|CpuDeadLoop\|0x0A6F8800' "$MENU" || echo "  OK: clean"
  echo "--- CSFTRST usage (must be only the safe RMW clear, no pulse) ---"
  grep -n 'CSFTRST' "$MENU"
  echo "--- DCTL writes ---"
  grep -n 'Usb'"$SUF"'Wr (USB'"$SUF"'_DCTL' "$MENU" | head -12
  echo "--- bringup done / widened poll ---"
  grep -n "bringup done\|poll: DCTL\|poll2:" "$MENU"
  ls -l "$MENU"
  exit 0
fi

rm -f "$B/FV/SILICIUM_UEFI.fd" "$B/FV/FVMAIN.Fv" "$B/FV/FVMAIN_COMPACT.Fv" "$B/FV/Guid.xref"
bash "build_$TAG.sh" "$TAG" 2>&1 | tee "/tmp/$TAG-build.log" | tail -8

bash pack_keys.sh "$TOOLS/qemu-fw/SILICIUM_UEFI-$TAG.fd" "$TAG" 2>&1 | tee "/tmp/$TAG-pack.log" | tail -4
cp -f "$OUT/Mu-vermeer-$TAG.img" "$OUT/Mu-vermeer-$TAG-fat.img"
cp -f "$OUT/Mu-vermeer-$TAG.img" "$OUT/K70-$TAG-$COPY.img"

echo "=== $TAG images ==="
sha256sum "$OUT/Mu-vermeer-$TAG.img" "$OUT/K70-$TAG-$COPY.img"
sha256sum "$TOOLS/qemu-fw/SILICIUM_UEFI-$TAG.fd"

cp "$B/FV/Guid.xref" "/mnt/d/本地项目-01/_tools/guid-$TAG.xref"
MENUD=$(find "$B" -name 'VermeerMenuDxe.efi' | head -1)
echo "--- Menu EFI: $MENUD ($(stat -c%s "$MENUD") B) ---"
python3 - "$MENUD" "$SUF" <<'PY'
import sys, pathlib
raw = pathlib.Path(sys.argv[1]).read_bytes(); suf = sys.argv[2]
print(f"  {sys.argv[1]} ({len(raw)} B)")
for m in (f"MENU{suf}", f"USB{suf}", "K70 UEFI DEBUG", "bringup done", "poll: DCTL", "poll2:"):
    print(f"    ascii {m}: {raw.count(m.encode())}  utf16 {m}: {raw.count(m.encode('utf-16-le'))}")
PY
echo "--- PEI sha (expect cfcfca5e... unchanged) ---"
python3 - <<PY
import struct, hashlib
buf = open("${TOOLS}/qemu-fw/SILICIUM_UEFI-${TAG}.fd", "rb").read()
def u16(b, o): return struct.unpack_from("<H", b, o)[0]
hdr = buf.find(b"_FVH", 0, 0x1000); base = hdr - 0x28
off = base + u16(buf, base + 0x30)
while off + 0x18 <= len(buf):
    ft = buf[off + 0x12]; sz = buf[off + 0x14] | (buf[off + 0x15] << 8) | (buf[off + 0x16] << 16)
    if sz < 0x18 or ft == 0xFF: break
    if ft == 0x03:
        body = buf[off + 0x18:off + sz]
        print("  SEC size", len(body), "sha", hashlib.sha256(body).hexdigest())
        break
    off = (off + sz + 7) & ~7
PY
