#!/usr/bin/env bash
set -u
EFI=/root/k70/uefi/Build/vermeerPkg/DEBUG_CLANGPDB/AARCH64/VermeerMenuDxe.efi
OUT=/tmp/menu155.asm
llvm-objdump -d "$EFI" > "$OUT"
echo "asm lines: $(wc -l < "$OUT")  efi size: $(stat -c%s "$EFI")"
echo
echo "=== 1) movz/movk materialisation of 0x100000 / 0x10 ==="
grep -nE 'movk?\s+w[0-9]+, #0x(10|f004|f010|f000)\b' "$OUT" | head -20
echo
echo "=== 2) any immediate 0xf0xx / 0x100000 in operands (add/orr/ldr) ==="
grep -nE '#0x(f004|f010|f014|f018|f084|100000|f000)\b' "$OUT" | head -30
echo
echo "=== 3) adrp targets + adds (GCC base 0x100000 cannot be adrp, but scan adds) ==="
grep -nE '\t(add|sub)\s+x[0-9]+, x[0-9]+, #0x(f0|10)[0-9a-f]*' "$OUT" | head -30
echo
echo "=== 4) ldr from computed reg near Usb155 print: count ldr w" ==="
grep -cE '\tldr\s+w[0-9]+, \[x[0-9]+' "$OUT" || true
echo
echo "=== 5) build log compile counts (keys155 vs keys154) ==="
for f in /mnt/d/本地项目-01/_tools/b155*.log /mnt/d/本地项目-01/_tools/b154*.log /mnt/d/本地项目-01/_tools/b152*.log; do
  [ -f "$f" ] || continue
  echo "$f: $(grep -c 'Building ' "$f" 2>/dev/null || echo 0) Building lines, $(grep -c 'PROGRESS - Success' "$f") success"
done
