#!/usr/bin/env bash
set -u
EFI=/root/k70/uefi/Binaries/vermeer/QcomPkg/Drivers/EnvDxe/EnvDxe.efi
ls -l "$EFI"
llvm-objdump -d --no-show-raw-insn "$EFI" > /tmp/env.dis 2>/dev/null || aarch64-linux-gnu-objdump -d "$EFI" > /tmp/env.dis
wc -l /tmp/env.dis
python3 - <<'PY'
import re
lines = open('/tmp/env.dis').read().splitlines()
cur = {}
hits = []
for idx, ln in enumerate(lines):
    m = re.search(r'^\s*([0-9a-f]+):\s+adrp\s+x(\d+),\s*0x([0-9a-f]+)', ln)
    if m:
        cur[m.group(2)] = int(m.group(3), 16)
        continue
    m = re.search(r'^\s*([0-9a-f]+):\s+add\s+x(\d+),\s*x(\d+),\s*#0x([0-9a-f]+)', ln)
    if m:
        page = cur.get(m.group(3))
        if page is None:
            continue
        val = page + int(m.group(4), 16)
        if 0xe090 <= val <= 0xe0a8:
            hits.append((idx, val, ln.strip()))
print("=== adrp/add -> DTB-extn HOB GUID ===", len(hits))
for idx, val, ln in hits:
    print(f"--- va=0x{val:x} {ln}")
    for j in range(max(0, idx - 16), min(len(lines), idx + 18)):
        print("   ", lines[j])
PY
