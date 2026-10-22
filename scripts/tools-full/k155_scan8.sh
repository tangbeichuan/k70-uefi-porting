#!/usr/bin/env bash
set -u
OUT=/tmp/menu155.asm
[ -s "$OUT" ] || llvm-objdump -d /root/k70/uefi/Build/vermeerPkg/DEBUG_CLANGPDB/AARCH64/VermeerMenuDxe.efi > "$OUT"
echo "=== 0x1c40-0x1d60 (GCC scan block) ==="
awk '/^ *1c[0-9a-f][0-9a-f]:/,/^ *1d6[0-9a-f]:/' "$OUT" | head -90
echo
echo "=== 0x1f00-0x1fd0 ==="
awk '/^ *1f[0-9a-f][0-9a-f]:/,/^ *1fd[0-9a-f]:/' "$OUT" | head -70
echo
echo "=== stores in whole Menu (str/strb) ==="
grep -nE '\tstr' "$OUT" | head -40
echo
echo "=== build log compile counts ==="
for f in /mnt/d/本地项目-01/_tools/b155*.log /mnt/d/本地项目-01/_tools/b154*.log /mnt/d/本地项目-01/_tools/b152*.log; do
  [ -f "$f" ] || continue
  n=$(grep -c 'Building ' "$f" 2>/dev/null || true)
  s=$(grep -c 'PROGRESS - Success' "$f" 2>/dev/null || true)
  echo "$f: Building=$n success=$s"
done
