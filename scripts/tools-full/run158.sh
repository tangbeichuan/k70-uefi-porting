#!/usr/bin/env bash
# run158.sh -- build keys158:
#   keys157 + early bring-up now disables the DWC3 device EVENT path
#   (DEVTEN=0, GEVNTADRLO/HI=0, GEVNTSIZ=0, GEVNTCOUNT cleared) BEFORE
#   PHYCFG clear + DCTL.RUN_STOP=1, with read-back printing.  Root cause per
#   lead m03692: DEVTEN=0x1277 stale while GEVNTADR likely 0 -> event DMA to
#   address 0 -> AXI decode error -> SError -> reset right after the host
#   started enumerating (VID_0000&PID_0002).
# lineage: keys157 -> keys158 (only VermeerDtbExtnDxe is expected to change).
set -e -o pipefail
TAG=keys158
TOOLS=/mnt/d/本地项目-01/_k70port_extract
B=/root/k70/uefi/Build/vermeerPkg/DEBUG_CLANGPDB
OUT=/mnt/d/本地项目-01/K70-UEFI-build
W=/mnt/d/本地项目-01/_k70port_extract/wsl

cd "$W"

# ---------------------------------------------------------------- build script
sed 's/keys157/keys158/g' build_keys157.sh > build_keys158.sh

echo "=== build_keys158.sh sanity ==="
echo "patch_usb157 count: $(grep -c 'patch_usb157.py' build_keys158.sh)  (want 1)"
echo "patch_nopmic138 count: $(grep -c 'patch_nopmic138.py' build_keys158.sh || true)  (want 0)"
echo "NO_HAL count: $(grep -c 'NO_HAL' build_keys158.sh || true)  (want 0)"
echo "UsbConfigDxe backup/restore trap count: $(grep -c 'UsbConfigDxe.patched.efi.bak143' build_keys158.sh || true)  (want 2)"

if [ "${1:-}" = "probe" ]; then
  echo "=== PROBE MODE: stop before build ==="
  python3 /mnt/d/本地项目-01/_tools/patch_menu101.py || exit 1
  python3 /mnt/d/本地项目-01/_tools/patch_usb157.py
  python3 /mnt/d/本地项目-01/_tools/patch_copy123.py || exit 1
  python3 /mnt/d/本地项目-01/_tools/patch_extn136.py || exit 1
  D=/root/k70/uefi/Platforms/Xiaomi/vermeerPkg/Drivers/VermeerDtbExtnDxe/VermeerDtbExtnDxe.c
  echo "--- keys158 DtbExtn effective source early block ---"
  grep -n 'USB158\|GEVNTADR\|DEVTEN\|RUN_STOP' "$D" | head -20
  ls -l "$D"
  python3 /mnt/d/本地项目-01/_tools/patch_gcc155.py check && echo "GCC row present (unexpected)" || echo "GCC row absent (expected)"
  exit 0
fi

# ---------------------------------------------------------------------- build
rm -f "$B/FV/SILICIUM_UEFI.fd" "$B/FV/FVMAIN.Fv" "$B/FV/FVMAIN_COMPACT.Fv" "$B/FV/Guid.xref"
bash build_keys158.sh "$TAG" 2>&1 | tee /tmp/$TAG-build.log | tail -8

# ----------------------------------------------------------------------- pack
bash pack_keys.sh "$TOOLS/qemu-fw/SILICIUM_UEFI-$TAG.fd" "$TAG" 2>&1 | tee /tmp/$TAG-pack.log | tail -4
cp -f "$OUT/Mu-vermeer-$TAG.img" "$OUT/Mu-vermeer-$TAG-fat.img"
cp -f "$OUT/Mu-vermeer-$TAG.img" "$OUT/K70-$TAG-DEVTEN-CLEAR.img"

echo "=== $TAG images ==="
sha256sum "$OUT/Mu-vermeer-$TAG.img" "$OUT/K70-$TAG-DEVTEN-CLEAR.img"
sha256sum "$TOOLS/qemu-fw/SILICIUM_UEFI-$TAG.fd"

# --------------------------------------------------------------- quick checks
cp "$B/FV/Guid.xref" "/mnt/d/本地项目-01/_tools/guid-$TAG.xref"
DTBEFI=$(find "$B" -name 'VermeerDtbExtnDxe.efi' | head -1)
echo "--- DtbExtn EFI: $DTBEFI ($(stat -c%s "$DTBEFI") B) ---"
python3 - "$DTBEFI" <<'PY'
import sys, pathlib
raw = pathlib.Path(sys.argv[1]).read_bytes()
print(f"  {sys.argv[1]} ({len(raw)} B)")
for m in ("USB158", "evt off", "early run", "[VBUS]", "selftest vadc"):
    print(f"    ascii {m}: {raw.count(m.encode())}")
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
