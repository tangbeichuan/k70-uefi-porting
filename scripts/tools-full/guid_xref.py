#!/usr/bin/env python3
import struct, subprocess, re, sys

def parse(EFI):
    d=open(EFI,'rb').read()
    pe=struct.unpack('<I', d[0x3c:0x40])[0]
    nsec=struct.unpack('<H', d[pe+6:pe+8])[0]
    optsz=struct.unpack('<H', d[pe+20:pe+22])[0]
    sect=pe+24+optsz
    secs=[]
    for i in range(nsec):
        o=sect+i*40
        name=d[o:o+8].rstrip(b'\x00').decode(errors='replace')
        vsz,va,rsz,roff=struct.unpack('<IIII', d[o+8:o+24])
        secs.append((name,va,vsz,roff,rsz))
    return d,secs

def va2off(secs,va):
    for n,v,sz,ro,rs in secs:
        if v<=va<v+max(sz,rs): return ro+(va-v)
    return None

GUIDb=bytes.fromhex('76b789035f62eb1183bec741a913de34')

def analyze(EFI, guiddata=GUIDb):
    d,secs=parse(EFI)
    offs=[]
    start=0
    while True:
        i=d.find(guiddata,start)
        if i<0: break
        offs.append(i); start=i+1
    print(f'### {EFI}  GUID occurrences at file offs:', [hex(x) for x in offs])
    dis=subprocess.run(['llvm-objdump','-d','--no-show-raw-insn',EFI],capture_output=True,text=True).stdout
    lines=dis.splitlines()
    # map each occurrence to VA
    def off2va(off):
        for n,v,sz,ro,rs in secs:
            if ro<=off<ro+rs: return v+(off-ro)
        return None
    vas=[off2va(o) for o in offs]
    print('   GUID VAs:', [hex(v) if v else None for v in vas])
    for va in vas:
        if va is None: continue
        page=va & ~0xfff; delta=va-page
        # find adrp page then add delta with same reg
        for idx,l in enumerate(lines):
            m=re.match(r'^\s*([0-9a-f]+):\s+adrp\s+x(\d+),\s*0x([0-9a-f]+)', l)
            if not m: continue
            if int(m.group(3),16)!=page: continue
            reg=m.group(2)
            for j in range(idx+1, min(idx+4,len(lines))):
                m2=re.match(r'^\s*[0-9a-f]+:\s+add\s+x'+reg+r',\s*x'+reg+r',\s*#(0x[0-9a-f]+|\d+)', lines[j])
                if m2 and int(m2.group(1),0)==delta:
                    print('   --- xref at line', idx, 'addr', m.group(1))
                    for k in range(max(0,idx-6), min(len(lines), j+14)):
                        print('     ', lines[k])
                    break

if __name__=='__main__':
    analyze(sys.argv[1])
