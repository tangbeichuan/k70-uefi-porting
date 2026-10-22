#!/bin/bash
# keys147: UsbConfigDxe IOMMU-init function tail + caller + protocol-install sites
set -u
B=/root/k70/uefi/Binaries/vermeer/QcomPkg/Drivers
U=$B/UsbConfigDxe/UsbConfigDxe.patched.efi
OUT=/mnt/d/本地项目-01/_tools/usb147_ucfg.log
: > $OUT

echo "== callers of bl 0x3f68 (IOMMU init) ==" >> $OUT
llvm-objdump -d --no-show-raw-insn "$U" | grep -nE "bl[[:space:]]+0x3f68" >> $OUT

echo "== InstallMultipleProtocolInterfaces sites [x,#0x148] ==" >> $OUT
llvm-objdump -d --no-show-raw-insn "$U" | grep -nE "ldr[[:space:]]+x[0-9]+, \[x[0-9]+, #0x148\]" >> $OUT

echo "== UsbConfigDxe 0x3d00-0x3e80 ==" >> $OUT
llvm-objdump -d --no-show-raw-insn --start-address=0x3d00 --stop-address=0x3e80 "$U" >> $OUT
echo "== UsbConfigDxe 0x41c0-0x4400 ==" >> $OUT
llvm-objdump -d --no-show-raw-insn --start-address=0x41c0 --stop-address=0x4400 "$U" >> $OUT
echo "== UsbConfigDxe 0x1000-0x1200 (entry) ==" >> $OUT
llvm-objdump -d --no-show-raw-insn --start-address=0x1000 --stop-address=0x1200 "$U" >> $OUT

echo "== GUID bytes at 0x130c0..0x130d8 ==" >> $OUT
python3 - "$U" <<'EOF' >> $OUT
import sys, uuid
d = open(sys.argv[1], "rb").read()
for o in range(0x130c0, 0x130e0, 0x10):
    print(hex(o), uuid.UUID(bytes_le=d[o:o+16]))
EOF
cat $OUT
