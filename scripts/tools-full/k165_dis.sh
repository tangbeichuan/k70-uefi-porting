#!/usr/bin/env bash
# k165_dis.sh -- prove keys165 Menu contains pull-up off/on around DCTL (0xc704).
set -e
E=$(find /root/k70/uefi/Build/vermeerPkg/DEBUG_CLANGPDB -name 'VermeerMenuDxe.efi' | head -1)
echo "Menu EFI: $E"
llvm-objdump -d "$E" > /tmp/m165.asm
python3 - <<'PY'
import re
rows=[]
for ln in open('/tmp/m165.asm', errors='ignore'):
    m=re.match(r"^\s*([0-9a-f]+):\s+([0-9a-f]+)\s+(\S+)\s*(.*)", ln)
    if m: rows.append((int(m.group(1),16), m.group(2), m.group(3), m.group(4).strip(), ln.rstrip()))
# find DCTL immediates and RUN_STOP RMW (and #0x7fffffff / orr #0x80000000 / tbnz bit31)
hits=[]
for a,enc,op,args,ln in rows:
    if any(k in ln for k in ("#0xc704", "#0x80000000", "#0x7fffffff", "#0xffffffff7fffffff")):
        hits.append(ln)
print("--- DCTL / RUN_STOP related instructions ---")
for ln in hits:
    print(ln)
print(f"count={len(hits)}")
PY
