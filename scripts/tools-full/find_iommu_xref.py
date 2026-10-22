import pathlib, struct
p = pathlib.Path('/root/k70/uefi/Binaries/vermeer/QcomPkg/Drivers/UFSDxe/UFSDxe.efi')
b = p.read_bytes()

# PE parsing
pe = struct.unpack_from('<I', b, 0x3c)[0]
nsec = struct.unpack_from('<H', b, pe+6)[0]
opt = pe+24
magic = struct.unpack_from('<H', b, opt)[0]
print('PE opt magic', hex(magic), 'sections', nsec)
sect_off = opt + struct.unpack_from('<H', b, pe+20)[0]
sections=[]
for i in range(nsec):
    off = sect_off + i*40
    name = b[off:off+8].rstrip(b'\0').decode()
    vsize, vaddr, rawsize, rawptr = struct.unpack_from('<IIII', b, off+8)
    sections.append((name, vaddr, vsize, rawptr, rawsize))
    print(f'  {name} va={vaddr:#x} vsz={vsize:#x} raw={rawptr:#x} rawsz={rawsize:#x}')

TARGET = 0x1bce8
text = [s for s in sections if s[0]=='.text'][0]
_, tva, tvsz, tptr, trawsz = text
data = b[tptr:tptr+trawsz]
words = struct.unpack_from('<%dI' % (len(data)//4), data, 0)

def adrp_target(w, pc):
    immlo = (w >> 29) & 0x3
    immhi = (w >> 5) & 0x7FFFF
    imm = (immhi << 2) | immlo
    if imm & (1 << 20): imm -= (1 << 21)
    return ((pc & ~0xFFF) + (imm << 12)) & 0xFFFFFFFFFFFFFFFF

hits=[]
for i in range(len(words)-8):
    w = words[i]
    if (w & 0x9F000000) != 0x90000000:   # adrp
        continue
    pc = tva + i*4
    base = adrp_target(w, pc)
    rd = w & 0x1F
    # look ahead 1..6 instrs for add rd, rd, #imm
    for j in range(1, 7):
        w2 = words[i+j]
        if (w2 & 0xFF000000) == 0x91000000:  # ADD (imm), 64-bit
            rn = (w2 >> 5) & 0x1F
            rd2 = w2 & 0x1F
            imm12 = (w2 >> 10) & 0xFFF
            sh = (w2 >> 22) & 0x3
            val = imm12 << (12 if sh == 1 else 0)
            if rn == rd and (base + val) == TARGET:
                hits.append(i)
                print('string xref at text offset', hex(tva + i*4), 'instr idx', i)
                break
print('hits', len(hits))
for h in hits[:3]:
    start = max(0, h-60)
    for k in range(start, h+6):
        print(hex(tva + k*4), hex(words[k]))
    print('---')