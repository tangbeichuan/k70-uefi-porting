#!/bin/bash
cd /root/k70/uefi || exit 1
echo "=== strings in NpaDxe.efi matching assert text ==="
strings -a Binaries/vermeer/QcomPkg/Drivers/NpaDxe/NpaDxe.efi | grep -n "Format != \|DebugLib.c\|ASSERT" | head -20
echo
echo "=== which prebuilt modules contain that literal ==="
for d in Binaries/vermeer/QcomPkg/Drivers/*/; do
  for f in "$d"*.efi; do
    [ -f "$f" ] || continue
    if strings -a "$f" 2>/dev/null | grep -q "Format != ((void"; then echo "HIT: $f"; fi
  done
done | head -20
echo
echo "=== Mu source: who prints 'Memory Allocation' ==="
grep -rn "Memory Allocation" --include=*.c . 2>/dev/null | head -5
