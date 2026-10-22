#!/bin/bash
set -u
LOG=/mnt/d/本地项目-01/_tools/usb147_guids2.log
: > "$LOG"
python3 - >> "$LOG" <<'PY'
import struct,glob,os,re
def rd(p,off,n):
    with open(p,'rb') as f:
        f.seek(off); return f.read(n)
def guid(b):
    d1,d2,d3=struct.unpack('<IHH',b[:8])
    return f"{d1:08X}-{d2:04X}-{d3:04X}-{b[8]:02X}{b[9]:02X}-"+''.join(f'{x:02X}' for x in b[10:16])
uci='/root/k70/uefi/Binaries/vermeer/QcomPkg/Drivers/UsbConfigDxe/UsbConfigDxe.patched.efi'
ufn='/root/k70/uefi/Binaries/vermeer/QcomPkg/Drivers/UsbfnDwc3Dxe/UsbfnDwc3Dxe.efi'
print("UsbConfigDxe .data GUID at 0x130c8:", guid(rd(uci,0x130c8,16)))
print("UsbConfigDxe .data GUID at 0x130b8:", guid(rd(uci,0x130b8,16)))
print("UsbConfigDxe .data GUID at 0x130d8:", guid(rd(uci,0x130d8,16)))
print("UsbfnDwc3Dxe .data GUID at 0x16098:", guid(rd(ufn,0x16098,16)))
print("UsbfnDwc3Dxe .data GUID at 0x160d8:", guid(rd(ufn,0x160d8,16)))
print("UsbfnDwc3Dxe .data GUID at 0x16038:", guid(rd(ufn,0x16038,16)))
print("UsbfnDwc3Dxe .data GUID at 0x16028:", guid(rd(ufn,0x16028,16)))
print("UsbfnDwc3Dxe .data GUID at 0x16058:", guid(rd(ufn,0x16058,16)))
print("UsbfnDwc3Dxe .data GUID at 0x16068:", guid(rd(ufn,0x16068,16)))
print("UsbfnDwc3Dxe .data GUID at 0x160a8:", guid(rd(ufn,0x160a8,16)))
print("UsbfnDwc3Dxe .data GUID at 0x160b8:", guid(rd(ufn,0x160b8,16)))
print("UsbfnDwc3Dxe .data GUID at 0x160e8:", guid(rd(ufn,0x160e8,16)))
print("UsbfnDwc3Dxe .data GUID at 0x160f8:", guid(rd(ufn,0x160f8,16)))
print("UsbfnDwc3Dxe .data GUID at 0x16118:", guid(rd(ufn,0x16118,16)))
print("UsbfnDwc3Dxe .data GUID at 0x16138:", guid(rd(ufn,0x16138,16)))
# resolve names from dec files
names={}
for dec in glob.glob('/root/k70/uefi/**/*.dec',recursive=True):
    try: txt=open(dec,encoding='utf-8',errors='ignore').read()
    except: continue
    for m in re.finditer(r'(\w+)\s*=\s*\{([^}]*)\}\s*$',txt,re.M):
        pass
    for line in txt.splitlines():
        if '=' in line and '{' in line:
            nm,val=line.split('=',1)
            nm=nm.strip().split()[-1]
            mg=re.search(r'([0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12})',val)
            if mg: names[mg.group(1).upper()]=nm
for g in ["E722B03F-B250-42CE-8EBD-5BD51812D037","32D2963A-2B0B-4A1C-9E0F-1E1B2F9A2F1B"]:
    print(g,'=>',names.get(g))
PY
cat "$LOG"
