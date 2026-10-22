#!/usr/bin/env bash
# k164_dis.sh -- keys164 Menu: prove EP0 arm order + raw trace + halt points.
set -e
E=$(find /root/k70/uefi/Build/vermeerPkg/DEBUG_CLANGPDB -name 'VermeerMenuDxe.efi' | head -1)
echo "Menu EFI: $E"
llvm-objdump -d "$E" > /tmp/m164.asm
echo "--- register immediates (DCTL/DEVTEN/DSTS/DALEPENA/GEVNT/DEPCMD) ---"
grep -nE '#0xc(110|120|200|400|404|408|40c|700|704|708|70c|720|800|80c)' /tmp/m164.asm | head -40
echo "--- usb164 init: DEPSTARTCFG/SETEPCONFIG/SETTRANSFRESOURCE/DALEPENA/RUN/arm sequence ---"
python3 - <<'PY'
import re
rows=[]
for ln in open('/tmp/m164.asm', errors='ignore'):
    m=re.match(r"^\s*([0-9a-f]+):\s+([0-9a-f]+)\s+(\S+)\s*(.*)", ln)
    if m: rows.append((int(m.group(1),16), m.group(3), m.group(4).strip(), ln.rstrip()))
# locate calls to the DEPCMD helper: helper usually starts with storing PAR2/PAR1/PAR0 then DEPCMD
# print the region 0x2200..0x2500 (init/build) compactly
print("--- region 0x2200..0x24c0 ---")
for a,op,args,ln in rows:
    if 0x2200 <= a < 0x24c0:
        print(ln)
PY
echo "--- self branches (CpuDeadLoop) count ---"
grep -cE '^\s*[0-9a-f]+:\s+14000000\s+b\s+0x' /tmp/m164.asm || true
