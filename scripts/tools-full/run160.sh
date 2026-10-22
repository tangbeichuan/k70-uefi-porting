#!/usr/bin/env bash
# run160.sh -- build keys160:
#   keys159 (minimal EP0 gadget in Menu) + stronger "why no SETUP" probes:
#     * 1 s poll line (DSTS/hlt22/speed/GEVNTCOUNT) with full register dump on change;
#     * first 8 raw device/endpoint events;
#     * per-DEPCMD completion (ok/status/param0);
#     * register snapshot: GCTL/DCFG/DEVTEN/DALEPENA/DEPCMD0/PAR0/PHYCFG/GEVNTSIZ;
#   bug-fix candidates applied:
#     * CSFTRST restores PHY-suspend defaults -> clear PHYCFG SUSPHY/ENBLSLPM/PHYSOFTRST
#       again plus 20 ms settle after the core soft reset;
#     * arm the SETUP TRB only after DCTL.RUN_STOP and DEVCTRLHLT clearing;
#     * GEVNTSIZ written as size only (bit31=0) like the vendor's non-masked path.
# lineage: keys159 -> keys160 (only VermeerMenuDxe is expected to change).
set -e -o pipefail
TAG=keys160
TOOLS=/mnt/d/本地项目-01/_k70port_extract
B=/root/k70/uefi/Build/vermeerPkg/DEBUG_CLANGPDB
OUT=/mnt/d/本地项目-01/K70-UEFI-build
W=/mnt/d/本地项目-01/_k70port_extract/wsl

cd "$W"

sed 's/keys159/keys160/g' build_keys159.sh > build_keys160.sh
python3 - "$W/build_keys160.sh" <<'PY'
import sys, pathlib
p = pathlib.Path(sys.argv[1])
s = p.read_text(encoding="utf-8")
old = "python3 /mnt/d/本地项目-01/_tools/patch_usb159.py"
assert s.count(old) == 1, f"patch_usb159 count = {s.count(old)}"
s = s.replace(old, "python3 /mnt/d/本地项目-01/_tools/patch_usb160.py", 1)
p.write_text(s, encoding="utf-8")
print("build_keys160.sh: menu patch -> patch_usb160.py")
PY

echo "=== build_keys160.sh sanity ==="
echo "patch_usb160 count: $(grep -c 'patch_usb160.py' build_keys160.sh)  (want 1)"
echo "patch_usb159 count: $(grep -c 'patch_usb159.py' build_keys160.sh || true)  (want 0)"
echo "patch_nopmic138 count: $(grep -c 'patch_nopmic138.py' build_keys160.sh || true)  (want 0)"
echo "NO_HAL count: $(grep -c 'NO_HAL' build_keys160.sh || true)  (want 0)"
echo "UsbConfigDxe backup/restore trap count: $(grep -c 'UsbConfigDxe.patched.efi.bak143' build_keys160.sh || true)  (want 2)"

if [ "${1:-}" = "probe" ]; then
  echo "=== PROBE MODE: stop before build ==="
  python3 /mnt/d/本地项目-01/_tools/patch_menu101.py || exit 1
  python3 /mnt/d/本地项目-01/_tools/patch_usb160.py || exit 1
  M=/root/k70/uefi/Platforms/Xiaomi/vermeerPkg/Drivers/VermeerMenuDxe/VermeerMenuDxe.c
  echo "--- keys160 Menu: key symbols ---"
  grep -n 'MENU160\|USB160\|Usb160Init\|Usb160Poll\|Usb160Stat\|Usb160EpCmd\|mUsb160CfgDesc\|K70 UEFI DEBUG\|RunMenu' "$M" | head -24
  echo "--- keys160 Menu must not touch GCC / CpuDeadLoop / old diag ---"
  grep -n '0x0010F004\|0x0010F000\|Usb150Wr\|CpuDeadLoop\|0x0A6F8800' "$M" || echo "  OK: clean"
  echo "--- keys160 probes present ---"
  grep -n 'evt raw\|poll: DSTS\|regs3:\|dep n=' "$M"
  ls -l "$M"
  exit 0
fi

rm -f "$B/FV/SILICIUM_UEFI.fd" "$B/FV/FVMAIN.Fv" "$B/FV/FVMAIN_COMPACT.Fv" "$B/FV/Guid.xref"
bash build_keys160.sh "$TAG" 2>&1 | tee /tmp/$TAG-build.log | tail -8

bash pack_keys.sh "$TOOLS/qemu-fw/SILICIUM_UEFI-$TAG.fd" "$TAG" 2>&1 | tee /tmp/$TAG-pack.log | tail -4
cp -f "$OUT/Mu-vermeer-$TAG.img" "$OUT/Mu-vermeer-$TAG-fat.img"
cp -f "$OUT/Mu-vermeer-$TAG.img" "$OUT/K70-$TAG-EVTRACE.img"

echo "=== $TAG images ==="
sha256sum "$OUT/Mu-vermeer-$TAG.img" "$OUT/K70-$TAG-EVTRACE.img"
sha256sum "$TOOLS/qemu-fw/SILICIUM_UEFI-$TAG.fd"

cp "$B/FV/Guid.xref" "/mnt/d/本地项目-01/_tools/guid-$TAG.xref"
MENUD=$(find "$B" -name 'VermeerMenuDxe.efi' | head -1)
echo "--- Menu EFI: $MENUD ($(stat -c%s "$MENUD") B) ---"
python3 - "$MENUD" <<'PY'
import sys, pathlib
raw = pathlib.Path(sys.argv[1]).read_bytes()
print(f"  {sys.argv[1]} ({len(raw)} B)")
for m in ("MENU160", "USB160", "K70 UEFI DEBUG", "Vermeer", "poll: DSTS", "evt raw"):
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
