#!/bin/bash
set -u
LOG=/mnt/d/本地项目-01/_tools/usb147_iface3.log
: > "$LOG"
EFI=/root/k70/uefi/Binaries/vermeer/QcomPkg/Drivers/UsbConfigDxe/UsbConfigDxe.patched.efi
echo "== callers of builder bl 0x8630 / 0x88d0 area ==" >> "$LOG"
grep -n -E 'bl\s+0x8630|bl\s+0x85|bl\s+0x863' /tmp/ucfg_if2.asm | head -20 >> "$LOG"
echo "== .reloc decode (targets in .data 0x13000-0x14000) ==" >> "$LOG"
python3 - "$EFI" >> "$LOG" <<'PY'
import struct,sys
p=open(sys.argv[1],'rb').read()
# find .reloc at file offset 0x14000 per objdump (VA=0x14000)
off=0x14000
out=[]
while off < len(p)-4:
    va,size=struct.unpack_from('<II',p,off)
    if size==0: break
    if va==0 and size==0: break
    idx=off+8
    end=off+size
    while idx<end:
        e=struct.unpack_from('<H',p,idx)[0]
        if e==0: idx+=2; continue
        typ=e>>12; rva=(va+(e&0xfff)) if typ in (3,) else None
        # AArch64: typ 3 = PE32+ DIR64? actually type 10 = DIR64
        if typ==10:
            tgt=va+(e&0xfff)
            out.append(tgt)
        idx+=2
    off+=size
print("reloc count:",len(out))
in_data=[t for t in out if 0x13000<=t<0x14000]
print("relocs into .data:",len(in_data))
print("first 40:",[hex(t) for t in in_data[:40]])
PY
echo "== raw .data reloc slots for iface struct 0x13488..0x13530 ==" >> "$LOG"
echo "(see above targets)" >> "$LOG"
cat "$LOG"
