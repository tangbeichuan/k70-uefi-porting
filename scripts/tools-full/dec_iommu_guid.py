import pathlib, struct, uuid
p = pathlib.Path('/root/k70/uefi/Binaries/vermeer/QcomPkg/Drivers/UFSDxe/UFSDxe.efi')
b = p.read_bytes()

def adrp_target(w, pc):
    immlo = (w >> 29) & 0x3
    immhi = (w >> 5) & 0x7FFFF
    imm = (immhi << 2) | immlo
    if imm & (1 << 20): imm -= (1 << 21)
    return ((pc & ~0xFFF) + (imm << 12)) & 0xFFFFFFFFFFFFFFFF

for w, pc, add in [(0xb0000020, 0x1773c, 0x960)]:
    base = adrp_target(w, pc)
    addr = base + add
    print('GUID addr =', hex(addr))
    raw = b[addr:addr+16]
    print('raw', raw.hex())
    g = uuid.UUID(bytes_le=raw)
    print('GUID', str(g).upper())