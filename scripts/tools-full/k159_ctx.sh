#!/usr/bin/env bash
set -e
E=/root/k70/uefi/Build/vermeerPkg/DEBUG_CLANGPDB/AARCH64/VermeerMenuDxe.efi
[ -s /tmp/menu159.asm ] || llvm-objdump -d "$E" > /tmp/menu159.asm
for a in 1c80 2044 2198 226c 2ad0; do
  echo "===== context around 0x$a ====="
  sed -n "/^    $a:/,+0p" /tmp/menu159.asm
  python3 - "$a" <<'PY'
import sys
a = int(sys.argv[1], 16)
lines = open('/tmp/menu159.asm').read().splitlines()
idx = [i for i, l in enumerate(lines) if l.strip().startswith(f'{a:05x}:') or l.strip().startswith(f'{a:04x}:')]
if idx:
    i = idx[0]
    for l in lines[max(0, i-3):i+8]:
        print(l)
PY
done
echo "===== any str to [xN] near movk #0xa60 (whole file, first 40) ====="
python3 - <<'PY'
lines = open('/tmp/menu159.asm').read().splitlines()
for i, l in enumerate(lines):
    if '#0xa60, lsl #16' in l:
        print('---')
        for x in lines[max(0, i-2):i+4]:
            print(x)
PY
