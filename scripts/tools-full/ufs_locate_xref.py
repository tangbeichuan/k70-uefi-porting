#!/usr/bin/env python3
import subprocess, re, sys, struct

EFI='/root/k70/uefi/Binaries/vermeer/QcomPkg/Drivers/UFSDxe/UFSDxe.efi'
d=open(EFI,'rb').read()
# parse PE
pe=struct.unpack('<I', d[0x3c:0x40])[0]
assert d[pe:pe+4]==b'PE\x00\x00'
nsec=struct.unpack('<H', d[pe+6:pe+8])[0]
optsz=struct.unpack('<H', d[pe+20:pe+22])[0]
sect=pe+24+optsz
secs=[]
for i in range(nsec):
    o=sect+i*40
    name=d[o:o+8].rstrip(b'\x00').decode()
    vsz,va,rsz,roff=struct.unpack('<IIII', d[o+8:o+24])
    secs.append((name,va,vsz,roff,rsz))
def off2va(off):
    for n,va,vsz,roff,rsz in secs:
        if roff <= off < roff+rsz:
            return va + (off-roff)
    return None
def va2off(va):
    for n,v,sz,roff,rsz in secs:
        if v <= va < v+max(sz,rsz):
            return roff + (va-v)
    return None

s=b'Failed to Locate DTBExtnProtocol 0x%x'
i=d.find(s)
print('string file off', hex(i), 'VA', hex(off2va(i)) if off2va(i) else None)
va_s=off2va(i)
print('sections:', [(n,hex(v),hex(ro),hex(rs)) for n,v,sz,ro,rs in secs])

dis=subprocess.run(['llvm-objdump','-d','--no-show-raw-insn',EFI],capture_output=True,text=True).stdout
lines=dis.splitlines()
# find adrp lines whose computed page == va_s page
hits=[]
for idx,l in enumerate(lines):
    m=re.search(r'^\s*([0-9a-f]+):\s+adrp\s+x(\d+),\s*0x([0-9a-f]+)', l)
    if not m: continue
    page=int(m.group(3),16)
    if abs(page - (va_s & ~0xfff)) <= 0x3000:
        # look ahead for add with same reg
        reg=m.group(2)
        for j in range(idx, min(idx+6, len(lines))):
            m2=re.search(r'^\s*[0-9a-f]+:\s+add\s+x'+reg+r',\s*x'+reg+r',\s*#(0x[0-9a-f]+|\d+)', lines[j])
            if m2:
                target=page+int(m2.group(1),0)
                if target==va_s:
                    hits.append((idx,j))
                break
print('xref hits:', hits)
for idx,j in hits:
    print('---- context ----')
    for k in range(max(0,idx-40), min(len(lines), j+6)):
        print(lines[k])
