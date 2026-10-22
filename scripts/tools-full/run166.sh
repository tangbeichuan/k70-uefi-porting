#!/usr/bin/env bash
# run166.sh -- build keys166 (SMMU bypass + vendor event-ring order) from keys161 lineage.
#
# keys166 = keys165 (EP0 gadget + pull-up replug + raw event trace + 20 s halt) plus:
#   * Apps SMMU bypass for DWC3 SID 0x40 (fallback 0x60) in Menu before the event
#     ring is programmed: SMMU-500 @ 0x15000000 (already mapped by the MemoryMapLib
#     "SMMU" region, so PEI is untouched);
#   * vendor event-ring write order ADDRHI -> ADDRLO -> SIZ -> COUNT with
#     GEVNTSIZ = 0x80000000 | 0x1000 (bit31 = interrupt masked, polled) and
#     DEVTEN = 0x1277 (vendor value);
#   * DMA below 4 GiB (AllocateMaxAddress 0xFFFFF000);
#   * bringup line prints evtaddr HI/LO.
#
#   bash run166.sh          # full build + pack
#   bash run166.sh probe    # patch only, print sanity, no build
set -e -o pipefail
TAG=${TAG:-keys166}
SUF=${SUF:-166}
COPY=${COPY:-SMMU-BYPASS}
TOOLS=/mnt/d/本地项目-01/_k70port_extract
B=/root/k70/uefi/Build/vermeerPkg/DEBUG_CLANGPDB
OUT=/mnt/d/本地项目-01/K70-UEFI-build
W=/mnt/d/本地项目-01/_k70port_extract/wsl
MENU=/root/k70/uefi/Platforms/Xiaomi/vermeerPkg/Drivers/VermeerMenuDxe/VermeerMenuDxe.c

cd "$W"

echo "=== $TAG (menu patch patch_usb$SUF.py, lineage keys161) ==="
sed "s/keys161/$TAG/g" build_keys161.sh > "build_$TAG.sh"
python3 - "$W/build_$TAG.sh" "$SUF" <<'PY'
import sys, pathlib
p = pathlib.Path(sys.argv[1]); suf = sys.argv[2]
s = p.read_text(encoding="utf-8")
old = "python3 /mnt/d/本地项目-01/_tools/patch_usb161.py"
assert s.count(old) == 1, f"patch_usb161 count = {s.count(old)}"
s = s.replace(old, f"python3 /mnt/d/本地项目-01/_tools/patch_usb{suf}.py", 1)
p.write_text(s, encoding="utf-8")
print(f"{p.name}: menu patch -> patch_usb{suf}.py")
PY

echo "=== build_$TAG.sh sanity ==="
echo "patch_usb$SUF count: $(grep -c "patch_usb$SUF.py" "build_$TAG.sh")  (want 1)"
echo "patch_usb161 count: $(grep -c 'patch_usb161.py' "build_$TAG.sh" || true)  (want 0)"
echo "patch_nopmic138 count: $(grep -c 'patch_nopmic138.py' "build_$TAG.sh" || true)  (want 0)"
echo "NO_HAL count: $(grep -c 'NO_HAL' "build_$TAG.sh" || true)  (want 0)"
echo "UsbConfigDxe backup/restore trap count: $(grep -c 'UsbConfigDxe.patched.efi.bak143' "build_$TAG.sh" || true)  (want 2)"

if [ "${1:-}" = "probe" ]; then
  echo "=== PROBE MODE: stop before build ==="
  python3 /mnt/d/本地项目-01/_tools/patch_menu101.py || exit 1
  python3 "/mnt/d/本地项目-01/_tools/patch_usb$SUF.py" || exit 1
  echo "--- SMMU bypass ---"
  grep -n 'smmu id0=\|smmu n=%u\|smmu valid=\|smmu bypass\|smmu created\|no free slot' "$MENU"
  echo "--- event ring order / vendor values ---"
  grep -n 'AllocateMaxAddress\|GEVNTADRHI\|GEVNTADRLO\|GEVNTSIZ\|GEVNTCOUNT, 0\|DEVTEN, 0x1277' "$MENU"
  echo "--- replug / window / halt ---"
  grep -n 'replug: pull-up off\|replug: pull-up on\|replug done\|evtaddr=\|done: evts=' "$MENU"
  echo "--- forbidden ---"
  grep -n 'AllocateAnyPages\|Usb150Wr\|0x0A6F8800\|0x0010F004\|0x0010F000' "$MENU" || echo "  OK: none"
  grep -n 'CSFTRST' "$MENU" || echo "  OK: no CSFTRST token"
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
for m in (f"MENU{suf}", f"[{suf}] smmu id0=", f"[{suf}] smmu bypass",
          f"[{suf}] smmu created", f"[{suf}] evt raw=", f"[{suf}] poll",
          f"[{suf}] done: evts=", f"[{suf}] replug: pull-up off", "replug done",
          f"evtaddr=", "K70 UEFI DEBUG", "CpuDeadLoop"):
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
