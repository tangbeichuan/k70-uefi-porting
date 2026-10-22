#!/usr/bin/env bash
# run165.sh -- build keys165 (EP0 + pull-up replug + raw trace + halt) from keys161 lineage.
#
# keys165 = keys164 (EP0 gadget, raw event trace, GOP clear, 8s halt) plus:
#   * after EP0 resources are configured and the core runs: clear DCTL.RUN_STOP
#     (D+ pull-up off) -> 150 ms -> set RUN_STOP (pull-up on) -> 150 ms, i.e. the
#     software equivalent of dwc3_gadget_pullup(0 -> 1). This forces the host to
#     restart enumeration, so connect-done / USB-reset / SETUP finally arrive;
#   * re-issues EP0 config if DALEPENA lost its bits across the stop/start;
#   * prints "[165] replug: pull-up off/on" + "replug done" for on-screen proof;
#   * event window 8 s -> 20 s, then "[165] done: ..." + CpuDeadLoop().
#
#   bash run165.sh          # full build + pack
#   bash run165.sh probe    # patch only, print sanity, no build
set -e -o pipefail
TAG=${TAG:-keys165}
SUF=${SUF:-165}
COPY=${COPY:-REPLUG-EP0}
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
  echo "--- replug path ---"
  grep -n "replug: pull-up off\|replug: pull-up on\|replug done\|ep cfg redo" "$MENU"
  echo "--- arm / window / halt ---"
  grep -n 'ArmSetup ()\|mTicks'"$SUF"' >= 20000\|mUsb'"$SUF"'Events >= 16\|CpuDeadLoop ()\|done: evts=' "$MENU"
  echo "--- forbidden ---"
  grep -n 'Usb150Wr\|0x0A6F8800\|0x0010F004\|0x0010F000' "$MENU" || echo "  OK: none"
  grep -n 'CSFTRST' "$MENU" || echo "  OK: no CSFTRST token"
  echo "--- EP0 config + DEPCMD trace ---"
  grep -n 'DEPSTARTCFG\|SETEPCONFIG\|SETTRANSFRESOURCE\|DALEPENA\|dep n=%u cmd=%02x' "$MENU" | head -20
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
for m in (f"MENU{suf}", f"[{suf}] evt raw=", f"[{suf}] dep evt raw=", f"[{suf}] poll",
          f"[{suf}] regs:", f"[{suf}] done: evts=", f"[{suf}] dep n=",
          f"[{suf}] replug: pull-up off", f"[{suf}] replug: pull-up on",
          "replug done", "K70 UEFI DEBUG", "CpuDeadLoop"):
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
