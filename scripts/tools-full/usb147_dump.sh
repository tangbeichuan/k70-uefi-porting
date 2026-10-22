#!/bin/bash
# keys147: entry-point & driver-binding disassembly of USB device-mode drivers
set -u
B=/root/k70/uefi/Binaries/vermeer/QcomPkg/Drivers
OUT=/mnt/d/本地项目-01/_tools/usb147_dump.log
: > $OUT

dump() {
  local n=$1 lo=$2 hi=$3
  local f=$(ls $B/$n/*.patched.efi 2>/dev/null | head -1)
  [ -z "$f" ] && f=$B/$n/$n.efi
  echo "=================== $n : $lo - $hi ===================" >> $OUT
  llvm-objdump -d --no-show-raw-insn --start-address=$lo --stop-address=$hi "$f" 2>/dev/null | sed -n '/<.text>/,$p' >> $OUT
}

# entries
dump UsbfnDwc3Dxe 0x1000 0x1200
dump UsbDeviceDxe 0x1000 0x1400
dump UsbMsdDxe 0x1000 0x1200
dump UsbInitDxe 0x1000 0x1100

# UsbfnDwc3Dxe driver-binding area
dump UsbfnDwc3Dxe 0x1200 0x1c60
# UsbDeviceDxe usbfn-io locate area
dump UsbDeviceDxe 0x1e00 0x2200

echo "=================== gBS protocol calls per module ===================" >> $OUT
for n in UsbfnDwc3Dxe UsbDeviceDxe UsbMsdDxe UsbInitDxe; do
  f=$(ls $B/$n/*.patched.efi 2>/dev/null | head -1)
  [ -z "$f" ] && f=$B/$n/$n.efi
  echo "--- $n" >> $OUT
  llvm-objdump -d --no-show-raw-insn "$f" 2>/dev/null \
    | grep -nE "ldr[[:space:]]+x[0-9]+, \[x[0-9]+, #(0x140|0x148|0x150|0x108|0x110|0x50|0x68|0xa8|0x138|0x98|0x118)\]" >> $OUT
done

cat $OUT
