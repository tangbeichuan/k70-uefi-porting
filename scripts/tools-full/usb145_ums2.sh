#!/bin/bash
# usb145_ums2.sh -- identify helper 0x5028 inside UsbMassStorageDxe and the
# protocol it looks up; also show the caller context that leads to 0x2f38.
set -u
E=/root/k70/uefi/Build/vermeerPkg/DEBUG_CLANGPDB/AARCH64/UsbMassStorageDxe.efi
llvm-objdump -d "$E" > /tmp/ums_full.asm
echo "===== 0x5000-0x50a0 (helper 0x5028) ====="
llvm-objdump -d --start-address=0x5000 --stop-address=0x50a0 "$E"
echo; echo "===== caller 0x1c60-0x1d40 ====="
llvm-objdump -d --start-address=0x1c60 --stop-address=0x1d40 "$E"
echo; echo "===== all callers of 0x5028 ====="
grep -n -E "bl\s+0x5028" /tmp/ums_full.asm | head
echo; echo "===== all references to 0x2f38 (callers) ====="
grep -n -E "bl\s+0x2f38" /tmp/ums_full.asm | head
echo; echo "===== dump .data GUID area 0x8000+ (file offset va-0x1000) ====="
python3 - <<'PY'
import struct
E="/root/k70/uefi/Build/vermeerpkg/DEBUG_CLANGPDB/AARCH64/UsbMassStorageDxe.efi"
E="/root/k70/uefi/Build/vermeerPkg/DEBUG_CLANGPDB/AARCH64/UsbMassStorageDxe.efi"
d=open(E,"rb").read()
def rd(va,n): return d[va-0x1000:va-0x1000+n]
def gs(b):
    a,c,e=struct.unpack("<IHH",b[:8]); return "%08X-%04X-%04X-%s-%s"%(a,c,e,b[8:10].hex().upper(),b[10:].hex().upper())
# scan whole file for GUID-looking 16-byte blocks with sane version nibble (4th byte high = 4|A|B|8|9)
i=0; seen=set()
while i+16<=len(d):
    b=d[i:i+16]
    if b[6]&0xF0==0x40:
        s=gs(b)
        if s not in seen and all(c.isalnum() or c=='-' for c in s):
            # only report if the GUID is referenced by an adrp+add in .text: cheap heuristic -> report all in .data/.rdata
            if i>=0x5400:
                seen.add(s)
                if len(seen)<40: print("fileoff 0x%05x  %s" % (i,s))
    i+=1
PY
