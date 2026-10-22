#!/usr/bin/env bash
# scan GCC register offsets referenced by vendor drivers
B=/root/k70/uefi/Binaries/vermeer/QcomPkg/Drivers
echo "=== UsbConfigDxe: immediates near GCC offsets (#0xf00x,#0xf01x,#0xf08x) ==="
cd /tmp || exit 1
llvm-objdump -d "$B/UsbConfigDxe/UsbConfigDxe.efi" > /tmp/ucfg.asm 2>/dev/null
grep -nE '#0xf0(0|1|8)[0-9a-f]|#0xf00[0-9a-f]' /tmp/ucfg.asm | head -30
echo
echo "=== UsbConfigDxe: 'mov w?, #0x100000' (GCC base) context ==="
grep -nE 'mov\s+w[0-9]+, #0x100000' /tmp/ucfg.asm | head -10
echo
echo "=== ClockDxe: immediates 0xf004/0xf010/0xf014/0xf018/0xf084 ==="
llvm-objdump -d "$B/ClockDxe/ClockDxe.efi" > /tmp/clock.asm 2>/dev/null
grep -nE '#0xf004|#0xf010|#0xf014|#0xf018|#0xf084|#0xf08' /tmp/clock.asm | head -20
echo
echo "=== ClockDxe raw bytes: LE 0x0000f004 / f010 / f014 / f018 / f084 around ==="
python3 - <<'PY'
import struct
p="/root/k70/uefi/Binaries/vermeer/QcomPkg/Drivers/ClockDxe/ClockDxe.efi"
b=open(p,'rb').read()
targets=[0x0f000,0x0f004,0x0f008,0x0f010,0x0f014,0x0f018,0x0f01c,0x0f080,0x0f084,0x0f088]
for t in targets:
    pat=struct.pack("<I",t)
    idx=[i for i in range(len(b)) if b.startswith(pat,i)]
    print(f"0x{t:06x}: {len(idx)} hits at {[hex(i) for i in idx[:6]]}")
PY
echo
echo "=== UsbfnDwc3Dxe: GCC offset immediates ==="
llvm-objdump -d "$B/UsbfnDwc3Dxe/UsbfnDwc3Dxe.efi" > /tmp/fn3.asm 2>/dev/null
grep -nE '#0xf004|#0xf010|#0xf014|#0xf018|#0xf08|#0x100000' /tmp/fn3.asm | head -20
