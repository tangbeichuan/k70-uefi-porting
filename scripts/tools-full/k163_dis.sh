#!/usr/bin/env bash
# k163_dis.sh -- keys163 Menu: confirm Blt/ClearScreen + CpuDeadLoop + event ring code.
set -e
E=$(find /root/k70/uefi/Build/vermeerPkg/DEBUG_CLANGPDB -name 'VermeerMenuDxe.efi' | head -1)
llvm-objdump -d "$E" > /tmp/m163.asm
python3 - <<'PY'
import re
rows = []
for ln in open('/tmp/m163.asm', errors='ignore'):
    m = re.match(r"^\s*([0-9a-f]+):\s+([0-9a-f]+)\s+(\S+)\s*(.*)", ln)
    if m:
        rows.append((int(m.group(1), 16), m.group(3), m.group(4).strip(), ln.rstrip()))
# 1) self branches = CpuDeadLoop
print("--- self-branch (CpuDeadLoop) candidates ---")
for a, op, args, ln in rows:
    if op == "b":
        t = re.match(r"^(?:0x)?([0-9a-f]+)", args)
        if t and int(t.group(1), 16) == a:
            print(f"  0x{a:x}: {ln.strip()}")
# 2) indirect Blt calls: look for 'blr' right after ldr ...[,#0x40] (EFI_GRAPHICS_OUTPUT_PROTOCOL.Blt offset 0x38? use raw search around)
print("--- bl/blr near GOP Blt (search imm 0x38/0x40 object loads) ---")
for a, op, args, ln in rows:
    if op == "blr" and 0x2500 <= a <= 0x2900:
        print(f"  0x{a:x}: {ln.strip()}")
# 3) event-ring immediate windows in the resident loop
print("--- event ring window (0x2500..0x2800) ---")
for a, op, args, ln in rows:
    if 0x2500 <= a <= 0x2800:
        print(ln)
PY
