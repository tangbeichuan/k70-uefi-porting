#!/bin/bash
# usb146_dis2.sh -- caller 0x8910, writers of gIommu, HALIOMMU install site
set -u
E=/tmp/ucfg145.efi
test -s "$E" || python3 /mnt/d/本地项目-01/_tools/cf146e.py /mnt/d/本地项目-01/_k70port_extract/qemu-fw/SILICIUM_UEFI-keys145.fd "$E"

echo "===== caller 0x8860-0x8990 ====="
llvm-objdump -d --start-address=0x8860 --stop-address=0x8990 "$E"
echo
echo "===== callers of 0x3f68 ====="
grep -n -E "bl\s+0x3f68|b\s+0x3f68" /tmp/ucfg145.asm 2>/dev/null || true
test -s /tmp/ucfg145.asm || llvm-objdump -d "$E" > /tmp/ucfg145.asm
grep -n -E "(bl|b)\s+0x3f68" /tmp/ucfg145.asm
echo
echo "===== all code touching gIommu 0x13768 (ldr/str with #0x768) ====="
grep -n -E "#0x768" /tmp/ucfg145.asm
echo
echo "===== gIommuCtx 0x13770 and buffer 0x13778 refs ====="
grep -n -E "#0x770|#0x778" /tmp/ucfg145.asm
echo
echo "===== HALIOMMUDxe: 54B6D3B4 GUID hits ====="
H=/root/k70/uefi/Binaries/vermeer/QcomPkg/Drivers/HALIOMMUDxe/HALIOMMUDxe.efi
python3 - "$H" <<'PY'
import sys
d=open(sys.argv[1],'rb').read()
pat=bytes.fromhex('b4d3b654335d914f86006c41d5deb19a')
hits=[];i=0
while True:
    i=d.find(pat,i)
    if i<0: break
    hits.append(i);i+=1
print("hits:",[hex(h) for h in hits])
PY
llvm-objdump -d "$H" > /tmp/hal146.asm 2>/dev/null
wc -l /tmp/hal146.asm
echo "--- adrp+add sites that build address 0xd??? (GUID area) ---"
grep -n -E "add\s+x[0-9]+, x[0-9]+, #0x" /tmp/hal146.asm | grep -E "#0x[0-9a-f]*(0|[1-9])[0-9a-f]{2}$" | head -40
echo
echo "--- gBS method offsets (InstallMultipleProtocolInterfaces 0x148 / Locate 0x140 / LocateHandleBuffer 0x138) ---"
grep -n -E "#0x(148|140|138|98|a8)" /tmp/hal146.asm | head -20
