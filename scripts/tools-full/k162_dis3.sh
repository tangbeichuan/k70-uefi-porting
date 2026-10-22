#!/usr/bin/env bash
# k162_dis3.sh -- dump the keys162 resident event drain loop (0x1e58..0x1fe0).
set -e
E=$(find /root/k70/uefi/Build/vermeerPkg/DEBUG_CLANGPDB -name 'VermeerMenuDxe.efi' | head -1)
python3 - "$E" <<'PY'
import re, subprocess, sys
dis = subprocess.run(["llvm-objdump", "-d", sys.argv[1]], capture_output=True, text=True).stdout
rows = []
for ln in dis.splitlines():
    m = re.match(r"^\s*([0-9a-f]+):", ln)
    if m:
        rows.append((int(m.group(1), 16), ln.rstrip()))
for a, ln in rows:
    if 0x1e58 <= a < 0x1f60:
        print(ln)
PY
