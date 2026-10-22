#!/bin/bash
set -u
cd /root/k70/uefi/Binaries/vermeer/QcomPkg/Drivers
OUT=/tmp/k148_regs.txt
: > "$OUT"
for f in UsbfnDwc3Dxe/UsbfnDwc3Dxe.efi UsbConfigDxe/UsbConfigDxe.patched.efi UsbDeviceDxe/UsbDeviceDxe.efi UsbInitDxe/UsbInitDxe.efi UsbMsdDxe/UsbMsdDxe.efi; do
  echo "########## $f" >> "$OUT"
  llvm-objdump -d "$f" > /tmp/k148_one.asm 2>/dev/null
  for c in c110 c200 c700 c704 c708 c70c c720 c400 c408 c40c; do
    hits=$(grep -n -E "#0x${c}([^0-9a-f]|$)" /tmp/k148_one.asm | head -8)
    if [ -n "$hits" ]; then
      echo "--- const 0x$c" >> "$OUT"
      while IFS=: read -r ln rest; do
        lo=$((ln-6)); [ $lo -lt 1 ] && lo=1
        hi=$((ln+10))
        sed -n "${lo},${hi}p" /tmp/k148_one.asm >> "$OUT"
        echo "....." >> "$OUT"
      done <<< "$hits"
    fi
  done
done
echo "WROTE $OUT lines=$(wc -l < "$OUT")"
grep -c '^---' "$OUT"