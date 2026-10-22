#!/usr/bin/env bash
# k166_dis.sh -- confirm keys166 Menu touches SMMU 0x15000000, uses vendor order and DEVTEN 0x1277.
set -e
E=$(find /root/k70/uefi/Build/vermeerPkg/DEBUG_CLANGPDB -name 'VermeerMenuDxe.efi' | head -1)
echo "Menu EFI: $E"
llvm-objdump -d "$E" > /tmp/m166.asm
python3 - <<'PY'
import re
rows=[]
for ln in open('/tmp/m166.asm', errors='ignore'):
    m=re.match(r"^\s*([0-9a-f]+):\s+([0-9a-f]+)\s+(\S+)\s*(.*)", ln)
    if m: rows.append((int(m.group(1),16), m.group(3), m.group(4).strip(), ln.rstrip()))
print("--- 0x1500 (SMMU base) immediates ---")
n=0
for a,op,args,ln in rows:
    if "0x1500" in args or "#0x15000000" in args or ("0x1500" in ln and "lsl" in ln):
        print(ln); n+=1
print("count=",n)
print("--- 0x800/0xc00 (SMR/S2CR) add immediates ---")
for a,op,args,ln in rows:
    if re.search(r"(#0x800|#0xc00)\b", args) and ("add" in op or "mov" in op):
        print(ln)
print("--- DEVTEN 0x1277 immediate ---")
for a,op,args,ln in rows:
    if "0x1277" in args:
        print(ln)
print("--- bit31 SIZ (0x80000000) orr before store ---")
for a,op,args,ln in rows:
    if op=="orr" and "0x80000000" in args:
        print(ln)
print("--- AllocateMaxAddress path: movz 0xffff / movk 0xffff ---")
for a,op,args,ln in rows:
    if "0xffff" in args and ("movz" in op or "movk" in op or "mov" in op):
        print(ln)
PY
