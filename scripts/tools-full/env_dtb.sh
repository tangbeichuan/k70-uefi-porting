#!/usr/bin/env bash
# Locate EnvDxe's DTB-extn HOB lookup and see what it does with it.
set -u
EFI=/root/k70/uefi/Build/vermeerPkg/DEBUG_CLANGPDB/AARCH64/EnvDxe.efi
[ -f "$EFI" ] || { echo "no $EFI"; exit 1; }
llvm-objdump -d --no-show-raw-insn "$EFI" > /tmp/env.dis
python3 - <<'PY'
import re
lines = open('/tmp/env.dis').read().splitlines()
# find adrp/add pairs that materialise the HOB GUID at file offset 0xe098 (VA 0xe098 here)
cur_adrp = {}
hits = []
for idx, ln in enumerate(lines):
    m = re.search(r'^\s*([0-9a-f]+):\s+adrp\s+x(\d+),\s*0x([0-9a-f]+)', ln)
    if m:
        cur_adrp[m.group(2)] = (int(m.group(1),16), int(m.group(3),16))
        continue
    m = re.search(r'^\s*([0-9a-f]+):\s+add\s+x(\d+),\s*x(\d+),\s*#0x([0-9a-f]+)', ln)
    if m:
        reg = m.group(3)
        c = cur_adrp.get(reg)
        if not c:
            continue
        val = c[1] + int(m.group(4),16)
        if 0xe090 <= val <= 0xe0a8:
            hits.append((idx, val, ln.strip()))
print("=== adrp/add referencing the DTB-extn HOB GUID (0xe098) ===")
for idx, val, ln in hits:
    print(f"  va=0x{val:x}  {ln}")
    for j in range(max(0,idx-14), min(len(lines), idx+16)):
        print("     ", lines[j])
    print()
# also print the whole 0x2b80..0x2c40 window (known InstallMultipleProtocolInterfaces site)
print("=== 0x2b80 - 0x2c40 (install site) ===")
printed = False
for ln in lines:
    m = re.search(r'^\s*([0-9a-f]+):', ln)
    if not m:
        continue
    va = int(m.group(1),16)
    if 0x2b80 <= va <= 0x2c40:
        print("  ", ln)
        printed = True
if not printed:
    print("  (window empty)")
PY
