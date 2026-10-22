#!/bin/bash
# usb145_uc2.sh -- deeper look at UsbConfigDxe: IOMMU map/unmap guards (0x4090,
# 0x4120), the 0x13780 flag that gates the teardown, and the clock code path.
set -u
E=/root/k70/uefi/Binaries/vermeer/QcomPkg/Drivers/UsbConfigDxe/UsbConfigDxe.patched.efi
ASM=/tmp/uc145.asm
[ -s "$ASM" ] || llvm-objdump -d "$E" > "$ASM"

echo "===== 0x4040-0x4160 (map path using gIommuCtx 0x13770) ====="
llvm-objdump -d --start-address=0x4040 --stop-address=0x4160 "$E"
echo; echo "===== 0x5340-0x5400 revisited compact ====="
llvm-objdump -d --start-address=0x5340 --stop-address=0x5400 "$E"

echo; echo "===== writes/reads of flag 0x13780 (adrp 0x13000 + off 0x780/0x781) ====="
grep -n -E "#0x780\]|#0x781\]" "$ASM"

echo; echo "===== clock protocol: references to strings 0x11135/0x11146 ====="
grep -n -E "#0x135\]|#0x146\]|#0x114\]" "$ASM" | head -20

echo; echo "===== callers of the teardown function (find function start) ====="
# find prologue before 0x5364 by walking back for 'sub sp' 
llvm-objdump -d --start-address=0x5100 --stop-address=0x5370 "$E" | head -80

echo; echo "===== Clock GUID 241AFAE6 in .data: who references it ====="
python3 - <<'PY'
import re,subprocess
E="/root/k70/uefi/Binaries/vermeer/QcomPkg/Drivers/UsbConfigDxe/UsbConfigDxe.patched.efi"
asm=open("/tmp/uc145.asm").read()
# find adrp/add pairs that produce 0x130f8
for m in re.finditer(r"adrp\s+(x\d+), 0x13000\s*\n\s*([0-9a-f]+):\s+add\s+\1, \1, #0xf8", asm):
    print("GUID 0x130f8 referenced near:", m.group(2))
PY
