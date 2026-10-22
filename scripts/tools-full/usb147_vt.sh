#!/usr/bin/env bash
set -u
U=/root/k70/uefi/Binaries/vermeer/QcomPkg/Drivers/UsbConfigDxe/UsbConfigDxe.patched.efi
T=/tmp/ucfg_vt.efi
cp -f "$U" "$T"
llvm-objdump -d --no-show-raw-insn "$T" > /tmp/ucfg_vt.asm 2>/dev/null
echo "=== vtable/template at .data 0x131f8 (file offset == VA) ==="
python3 - <<'PY'
import struct
p = '/tmp/ucfg_vt.efi'
b = open(p,'rb').read()
# .data VA 0x13000 == file 0x13000
base = 0x131F8
for off in range(0, 0xC0, 8):
    v = struct.unpack_from('<Q', b, base+off)[0]
    print('  +0x%02x = 0x%016x' % (off, v))
PY
echo
echo "=== code refs to DWC3/QSCRATCH registers inside UsbConfigDxe ==="
grep -nE '0xc700|0xc704|0xc110|#0xa600000|0xa6f8800|0xa6f880' /tmp/ucfg_vt.asm | head -30
echo
echo "=== code refs to QSCRATCH 0xA6F8xxx patterns (mov/movk pairs) ==="
grep -nE 'mov[zk]?[[:space:]]+w?[0-9]+, #0xa6f8|movk[[:space:]]+w?[0-9]+, #0xa6f, lsl' /tmp/ucfg_vt.asm | head -20
echo
echo "=== functions that mention 0x88e1 (QUSB2 PHY / eUSB2 clock regs) ==="
grep -nE '#0x88e1' /tmp/ucfg_vt.asm | head -20
echo
echo "=== calls / tail calls to addresses 0x169c 0x1730 (iface method slots) ==="
grep -nE '<0x(169c|1730|1500|1600)>' /tmp/ucfg_vt.asm | head -20
