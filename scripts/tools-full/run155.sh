#!/usr/bin/env bash
# run155.sh -- build keys155 = keys152 + GCC PEI region + read-only GCC/DWC3 Menu diag.
set -e -o pipefail
TOOLS=/mnt/d/本地项目-01/_k70port_extract
OUT=/mnt/d/本地项目-01/K70-UEFI-build
B=/root/k70/uefi/Build/vermeerPkg/DEBUG_CLANGPDB
WSLD=/mnt/d/本地项目-01/_k70port_extract/wsl
TL=/mnt/d/本地项目-01/_tools
cd "$WSLD"

# ---- derive keys155 lineage from keys152 -----------------------------------
sed 's/keys152/keys155/g' build_keys152.sh > build_keys155.sh
python3 - <<'PY'
import pathlib
p = pathlib.Path("build_keys155.sh")
s = p.read_text()
old = "python3 /mnt/d/本地项目-01/_tools/patch_usb152.py"
new = old + " && python3 /mnt/d/本地项目-01/_tools/patch_usb155.py && python3 /mnt/d/本地项目-01/_tools/patch_gcc155.py add"
if "patch_usb155.py" not in s:
    if old not in s:
        raise SystemExit("FATAL: patch_usb152.py not in build chain")
    s = s.replace(old, new, 1)
    p.write_text(s)
print("chain:", [l for l in s.splitlines() if "patch_usb155" in l][:1])
PY
grep -q 'patch_usb155.py' build_keys155.sh || { echo "FATAL: patch_usb155 not in build chain"; exit 1; }
grep -q 'patch_gcc155.py add' build_keys155.sh || { echo "FATAL: patch_gcc155 not in build chain"; exit 1; }

# ---- build -----------------------------------------------------------------
rm -f "$B/FV/SILICIUM_UEFI.fd" "$B/FV/FVMAIN.Fv" "$B/FV/FVMAIN_COMPACT.Fv" "$B/FV/Guid.xref"
bash build_keys155.sh keys155 2>&1 | tee /tmp/keys155-build.log | tail -8
grep -q "PROGRESS - Success" /tmp/keys155-build.log || { echo "FATAL: build did not finish"; exit 1; }

cp -f "$B/FV/Guid.xref" "$TL/guid-keys155.xref"
bash pack_keys.sh "$TOOLS/qemu-fw/SILICIUM_UEFI-keys155.fd" keys155 2>&1 | tee /tmp/keys155-pack.log | tail -4
cp -f "$OUT/Mu-vermeer-keys155.img" "$OUT/K70-keys155-GCC-READ.img"

# ---- evidence: GCC row must be in the PEI memory map -----------------------
python3 - <<'PY'
import struct, uuid, hashlib
FD = "/mnt/d/本地项目-01/_k70port_extract/qemu-fw/SILICIUM_UEFI-keys155.fd"
def u16(b,o): return struct.unpack_from("<H",b,o)[0]
def u64(b,o): return struct.unpack_from("<Q",b,o)[0]
buf = open(FD,'rb').read()
hdr = buf.find(b"_FVH",0,0x1000); base = hdr-0x28
off = base + u16(buf, base+0x30); end = min(len(buf), base+u64(buf, base+0x20))
while off+0x18 <= end:
    ft = buf[off+0x12]; sz = buf[off+0x14]|(buf[off+0x15]<<8)|(buf[off+0x16]<<16)
    if sz < 0x18 or ft == 0xFF: break
    if ft == 0x03:
        body = buf[off+0x18:off+sz]
        print("SEC/PEI FFS size=%d sha256=%s" % (len(body), hashlib.sha256(body).hexdigest()))
        for n in (b"GCC\x00", b"USB\x00", b"PERIPH_SS\x00", b"UFS\x00"):
            print("  region-name %r count=%d" % (n, body.count(n)))
        break
    off = (off+sz+7) & ~7
PY

echo "=== Menu EFI markers ==="
MENUD=$(find "$B" -path '*VermeerMenuDxe*' -name 'VermeerMenuDxe.efi' | head -1)
echo "menu: $MENUD size=$(stat -c%s "$MENUD")"
llvm-objdump -d "$MENUD" > /tmp/menu155.asm
grep -c 'mov\s*w0, #0x100000' /tmp/menu155.asm || true
strings -el "$MENUD" | grep -E 'MENU155|USB155' | head -12

echo "=== artifacts ==="
sha256sum "$TOOLS/qemu-fw/SILICIUM_UEFI-keys155.fd" \
          "$OUT/Mu-vermeer-keys155.img" \
          "$OUT/K70-keys155-GCC-READ.img"

# ---- restore the source tree (row removed, mtime forced so next build recompiles)
python3 "$TL/patch_gcc155.py" restore
python3 "$TL/patch_gcc155.py" check || echo "  (GCC row correctly absent after restore)"
echo "=== DONE ==="
