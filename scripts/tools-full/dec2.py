import pathlib, struct, uuid
b = pathlib.Path('/root/k70/uefi/Binaries/vermeer/QcomPkg/Drivers/UFSDxe/UFSDxe.efi').read_bytes()

def adrp(w, pc):
    immlo=(w>>29)&3; immhi=(w>>5)&0x7FFFF
    imm=(immhi<<2)|immlo
    if imm&(1<<20): imm-=(1<<21)
    rd=w&0x1F
    return rd, ((pc&~0xFFF)+(imm<<12)) & 0xFFFFFFFFFFFFFFFF

def addi(w):
    rd=w&0x1F; rn=(w>>5)&0x1F; imm12=(w>>10)&0xFFF; sh=(w>>22)&3
    return rd, rn, imm12 << (12 if sh==1 else 0)

words={0x17738:0xf0000028,0x1773c:0xb0000020,0x17740:0x91096000,0x17744:0x910023e2,0x17748:0xaa1f03e1,0x1774c:0xf9403d08,0x17750:0xf940a108,0x17754:0xd63f0100}
for pc,w in words.items():
    if (w & 0x9F000000)==0x90000000:
        print(hex(pc),'adrp',hex(w),adrp(w,pc))
    elif (w & 0xFF000000)==0x91000000:
        print(hex(pc),'add ',hex(w),addi(w))
    else:
        print(hex(pc),'other',hex(w))

rd,base = adrp(0xb0000020,0x1773c)
rd2,rn,off = addi(0x91096000)
addr = base+off
print('GUID addr',hex(addr),'off',hex(off))
raw=b[addr:addr+16]
print(raw.hex())
try:
    print(uuid.UUID(bytes_le=raw))
except Exception as e:
    print('err',e)