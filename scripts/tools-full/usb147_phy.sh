#!/bin/bash
# keys147: find PHY/DTB init code paths + call dependencies in UsbfnDwc3Dxe / UsbDeviceDxe
set -u
B=/root/k70/uefi/Binaries/vermeer/QcomPkg/Drivers
OUT=/mnt/d/本地项目-01/_tools/usb147_phy.log
: > $OUT

for spec in "UsbfnDwc3Dxe:0x15000:0x26b" "UsbfnDwc3Dxe:0x15000:0x37f" "UsbfnDwc3Dxe:0x15000:0x2b2" "UsbDeviceDxe:0x9000:0x429" "UsbDeviceDxe:0x9000:0x53d" "UsbDeviceDxe:0x9000:0x470"; do
  n=$(echo "$spec" | cut -d: -f1)
  page=$(echo "$spec" | cut -d: -f2)
  imm=$(echo "$spec" | cut -d: -f3)
  f=$(ls $B/$n/*.patched.efi 2>/dev/null | head -1)
  [ -z "$f" ] && f=$B/$n/$n.efi
  echo "########## $n : adrp $page + add #$imm ##########" >> $OUT
  llvm-objdump -d --no-show-raw-insn "$f" 2>/dev/null > /tmp/u147_$n.asm
  # find adrp to page then add with imm within next 3 insns
  grep -nE "adrp[[:space:]]+x[0-9]+, 0x$page" /tmp/u147_$n.asm | while IFS=: read -r ln rest; do
    seg=$(sed -n "$((ln)),$((ln+3))p" /tmp/u147_$n.asm)
    if echo "$seg" | grep -qE "add[[:space:]]+x[0-9]+, x[0-9]+, #$imm"; then
      addr=$(echo "$rest" | awk '{print $1}')
      echo "--- ref near $addr ---" >> $OUT
      sed -n "$((ln-30)),$((ln+40))p" /tmp/u147_$n.asm >> $OUT
    fi
  done
done

echo "########## bl callers of DTBExtn-locate wrappers ##########" >> $OUT
cat $OUT
