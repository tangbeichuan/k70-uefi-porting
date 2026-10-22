#!/bin/bash
# usb145_win.sh -- dump selected windows of UsbConfigDxe.patched.efi and locate
# the ClockProtocol / IOMMU global usage.
set -u
E=/root/k70/uefi/Binaries/vermeer/QcomPkg/Drivers/UsbConfigDxe/UsbConfigDxe.patched.efi
ASM=/tmp/usb145_uc.asm
if [ ! -s "$ASM" ]; then llvm-objdump -d "$E" > "$ASM"; fi

dump() { # $1=lo $2=hi
  awk -v lo=$((16#$1)) -v hi=$((16#$2)) '{ a=strtonum("0x"$1); if (substr($1,length($1))==":" ) a=strtonum("0x"substr($1,1,length($1)-1)); if (a>=lo && a<hi) print }' "$ASM"
}

echo "===== 0x52d0-0x5480 (global 0x13770 usage) ====="
llvm-objdump -d --start-address=0x52d0 --stop-address=0x5480 "$E"
echo; echo "===== 0x3f50-0x4010 (IOMMU locate + harden site) ====="
llvm-objdump -d --start-address=0x3f50 --stop-address=0x4010 "$E"
echo; echo "===== 0x4520-0x4620 (global 0x137e0 usage) ====="
llvm-objdump -d --start-address=0x4520 --stop-address=0x4620 "$E"

echo; echo "===== ClockProtocol / DisableUsbClocks strings ====="
strings -t x "$E" | grep -i -E "clock|DisableUsb" | head -20

echo; echo "===== all instructions referencing 0x13768/0x13770 (gIommu) ====="
grep -n -E "#0x768\]|#0x770\]" "$ASM" | head -40

echo; echo "===== all instructions referencing GUID 241AFAE6 (clock) ====="
python3 - <<'PY'
import struct
d=open("/root/k70/uefi/Binaries/vermeer/QcomPkg/Drivers/UsbConfigDxe/UsbConfigDxe.patched.efi","rb").read()
g=bytes.fromhex("e6fa1a245f886c4fa7eac28eab79c3e5")  # 241AFAE6-885F-4F6C-A7EA-C28EAB79C3E5
i=0
while True:
    i=d.find(g,i)
    if i<0: break
    print("clock GUID bytes at file offset 0x%x" % i)
    i+=1
PY
