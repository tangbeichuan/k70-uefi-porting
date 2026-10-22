#!/bin/bash
# usb146_dis.sh -- disassemble the failing UsbConfigDxe path + HALIOMMU protocol install
set -u
python3 /mnt/d/本地项目-01/_tools/cf146e.py /mnt/d/本地项目-01/_k70port_extract/qemu-fw/SILICIUM_UEFI-keys145.fd /tmp/ucfg145.efi
E=/tmp/ucfg145.efi

echo "===== UsbConfigDxe 0x3F68-0x40A0 (IOMMU init) ====="
llvm-objdump -d --start-address=0x3f68 --stop-address=0x40a0 "$E"
echo
echo "===== UsbConfigDxe 0x40A0-0x41D0 (continuation / already-init path) ====="
llvm-objdump -d --start-address=0x40a0 --stop-address=0x41d0 "$E"
echo
echo "===== caller: 0x8860-0x8990 ====="
llvm-objdump -d --start-address=0x8860 --stop-address=0x8990 "$E"
echo
echo "===== which functions call 0x3f68 (scan whole .text) ====="
llvm-objdump -d "$E" > /tmp/ucfg145.asm
grep -n -E "bl\s+0x3f68|b\s+0x3f68" /tmp/ucfg145.asm | head
echo
echo "===== HALIOMMUDxe: GUID 54B6D3B4 usage ====="
H=/root/k70/uefi/Binaries/vermeer/QcomPkg/Drivers/HALIOMMUDxe/HALIOMMUDxe.efi
grep -abo $'\xb4\xd3\xb6\x54\x33\x5d\x91\x4f\x86\x00\x6c\x41\xd5\xde\xb1\x9a' "$H" || python3 - "$H" <<'PY'
import sys
d=open(sys.argv[1],'rb').read()
pat=bytes.fromhex('b4d3b654335d914f86006c41d5deb19a')
print("54B6D3B4 GUID hits in HALIOMMUDxe:", end=" ")
i=0; hits=[]
while True:
    i=d.find(pat,i)
    if i<0: break
    hits.append(i); i+=1
print([hex(h) for h in hits])
PY
llvm-objdump -d "$H" > /tmp/hal146.asm
echo "--- instructions referencing the GUID (adrp+add) ---"
grep -n -E "add\s+x[0-9]+, x[0-9]+, #0x[0-9a-f]{3}$" /tmp/hal146.asm | head -20
echo
echo "===== HALIOMMUDxe InstallMultipleProtocolInterfaces / LocateProtocol sites ====="
grep -n -E "#0x130|#0x140|#0x148|#0xa8|#0xc0" /tmp/hal146.asm | head -20
