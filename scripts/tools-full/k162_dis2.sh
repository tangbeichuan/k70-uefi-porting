#!/usr/bin/env bash
# k162_dis2.sh -- disassemble the keys162 event-drain region for the report.
set -e
E=$(find /root/k70/uefi/Build/vermeerPkg/DEBUG_CLANGPDB -name 'VermeerMenuDxe.efi' | head -1)
llvm-objdump -d "$E" > /tmp/m162.asm
awk '
  /^[[:space:]]+[0-9a-f]+:/ {
    split($1, a, ":"); addr = strtonum("0x" a[1]);
  }
' /tmp/m162.asm 2>/dev/null || true
python3 - "$E" <<'PY'
import re, subprocess, sys
dis = subprocess.run(["llvm-objdump", "-d", sys.argv[1]], capture_output=True, text=True).stdout
rows = []
for ln in dis.splitlines():
    m = re.match(r"^\s*([0-9a-f]+):", ln)
    if m:
        rows.append((int(m.group(1), 16), ln.rstrip()))
def dump(lo, hi, tag):
    print(f"--- {tag} 0x{lo:x}..0x{hi:x} ---")
    for a, ln in rows:
        if lo <= a < hi:
            print(ln)
dump(0x1c40, 0x1d80, "event setup + drain")
dump(0x1d80, 0x1e60, "poll/stat")
PY
