#!/bin/bash
# usb145_ums.sh -- dump the suspect UsbMassStorageDxe region (RVA 0x2FF0) and
# find the GUID / strings around it.
set -u
E=/root/k70/uefi/Build/vermeerPkg/DEBUG_CLANGPDB/AARCH64/UsbMassStorageDxe.efi
[ -f "$E" ] || E=/root/k70/uefi/Binaries/vermeer/MdeModulePkg/Bus/Usb/UsbMassStorageDxe/UsbMassStorageDxe.efi
echo "module: $E"
llvm-readobj --sections "$E" | grep -E "Name:|VirtualAddress:|VirtualSize:|PointerToRawData:"
echo; echo "===== 0x2e80-0x3060 ====="
llvm-objdump -d --start-address=0x2e80 --stop-address=0x3060 "$E"
echo; echo "===== bl callers/callees around function start ====="
llvm-objdump -d "$E" > /tmp/ums.asm
grep -n -E "bl\s+0x2[0-9a-f]{3}\b" /tmp/ums.asm | head -20
echo; echo "===== strings ====="
strings -t x "$E" | grep -i -E "usb|mass|storage|protocol" | head -30
echo; echo "===== GUID dwords referenced in the window ====="
python3 - <<'PY'
import re,subprocess
E="/root/k70/uefi/Build/vermeerPkg/DEBUG_CLANGPDB/AARCH64/UsbMassStorageDxe.efi"
d=open(E,"rb").read()
# print all GUID-looking 16-byte patterns whose third group looks sane, for reference
out=subprocess.run(["llvm-objdump","-d","--start-address=0x2e80","--stop-address=0x3060",E],capture_output=True,text=True).stdout
for L in out.split("\n"):
    m=re.search(r"adrp\s+x(\d+), (0x[0-9a-f]+)",L)
    if m: print("adrp x%s -> %s" % (m.group(1), m.group(2)))
PY
