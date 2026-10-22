set +e
D=/root/k70/uefi/Binaries/vermeer/QcomPkg/Drivers/UsbConfigDxe/UsbConfigDxe.efi
python3 - "$D" <<'PY'
import sys, struct, re
p = sys.argv[1]
d = open(p,'rb').read()
# find the format string offset
s = b'%a: failed to locate PMIC version protocol\n\x00'
so = d.find(s)
print("fmt off", hex(so))
# PE sections to map RVA->file offset
e_lfanew = struct.unpack_from('<I', d, 0x3c)[0]
nsec = struct.unpack_from('<H', d, e_lfanew+6)[0]
opt = e_lfanew+24
magic = struct.unpack_from('<H', d, opt)[0]
sec_off = opt + (240 if magic==0x20b else 224)
secs=[]
for i in range(nsec):
    o = sec_off + i*40
    name = d[o:o+8].rstrip(b'\x00').decode()
    vsize, va, rsize, rptr = struct.unpack_from('<IIII', d, o+8)
    secs.append((name, va, vsize, rptr, rsize))
print(secs)
def rva_to_off(rva):
    for n,va,vs,rp,rs in secs:
        if va <= rva < va+max(vs,rs):
            return rp + (rva-va)
    return None
# data directory -> reloc / debug irrelevant; find code xref to the string via ADRP/ADD is hard;
# instead scan for GUID-like 16-byte blobs in .rdata and print those near the string section
for n,va,vs,rp,rs in secs:
    if n == '.rdata' or n == '.text':
        continue
print("--- scan all sections for likely protocol GUIDs (heuristic) ---")
seen=set()
for n,va,vs,rp,rs in secs:
    start=rp; end=rp+rs
    for off in range(start, end-16, 4):
        b=d[off:off+16]
        # GUID heuristic: first 4 bytes big-ish, then 2,2,2 then 6
        if len(set(b)) < 6: continue
        if b in seen: continue
        seen.add(b)
        u1,u2,u3,u4,u5 = struct.unpack('<IHH', b[:8]) + (b[8],)
        # skip obvious ascii
        if all(32 <= x < 127 for x in b[:8]): continue
PY