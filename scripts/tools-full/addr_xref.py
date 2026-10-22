#!/usr/bin/env python3
"""Find adrp+add pairs that materialise a given VA inside an AArch64 PE.

Usage: addr_xref.py <efi> <hex_va> [window_bytes]

The point: vendor UEFI drivers keep protocol interface pointers and string literals in
.rodata and reference them with adrp/add.  Given the VA of a string or GUID we can walk the
.text instructions, pair each adrp with the following add on the same register, and print the
surrounding disassembly so the call sequence (which interface offset is invoked, with which
arguments) becomes readable.
"""
import struct
import subprocess
import sys
import tempfile
import os


def pe_sections(data):
    e_lfanew = struct.unpack_from('<I', data, 0x3C)[0]
    assert data[e_lfanew:e_lfanew + 4] == b'PE\0\0'
    coff = e_lfanew + 4
    nsec = struct.unpack_from('<H', data, coff + 2)[0]
    opt_size = struct.unpack_from('<H', data, coff + 16)[0]
    opt = coff + 20
    magic = struct.unpack_from('<H', data, opt)[0]
    pe32plus = (magic == 0x20b)
    sec_off = opt + opt_size
    secs = []
    for i in range(nsec):
        off = sec_off + i * 40
        name = data[off:off + 8].rstrip(b'\0').decode('latin1')
        vsize, vaddr, rawsize, rawptr = struct.unpack_from('<IIII', data, off + 8)
        secs.append((name, vaddr, vsize, rawptr, rawsize))
    image_base = struct.unpack_from('<Q' if pe32plus else '<I', data, opt + 24)[0]
    return secs, image_base


def main():
    if len(sys.argv) < 3:
        print(__doc__)
        return 2
    path = sys.argv[1]
    target = int(sys.argv[2], 16)
    window = int(sys.argv[3], 0) if len(sys.argv) > 3 else 0x40

    data = open(path, 'rb').read()
    secs, image_base = pe_sections(data)
    print(f'image base 0x{image_base:x}')

    # targets inside the image are file-offset addressable here (PE sections are 1:1 in these
    # vendor binaries), so treat the given VA as it is, but also accept image-relative input.
    cands = {target}
    if target >= image_base:
        cands.add(target - image_base)
    print('candidates:', [hex(c) for c in cands])

    text = [s for s in secs if s[0] == '.text']
    if not text:
        print('no .text')
        return 1
    name, vaddr, vsize, rawptr, rawsize = text[0]
    print(f'.text vaddr=0x{vaddr:x} vsize=0x{vsize:x} rawptr=0x{rawptr:x} rawsize=0x{rawsize:x}')

    hits = []
    n = vsize // 4
    for i in range(n):
        pc = vaddr + i * 4
        ins = struct.unpack_from('<I', data, rawptr + i * 4)[0]
        if (ins & 0x9F000000) != 0x90000000:      # adrp
            continue
        rd = ins & 0x1F
        immlo = (ins >> 29) & 0x3
        immhi = (ins >> 5) & 0x7FFFF
        imm = (immhi << 2) | immlo
        if imm & (1 << 20):
            imm -= 1 << 21
        base = (pc & ~0xFFF) + (imm << 12)
        # look ahead a few instructions for add rd, rd, #imm
        for k in range(1, 5):
            j = i + k
            if j >= n:
                break
            ins2 = struct.unpack_from('<I', data, rawptr + j * 4)[0]
            if (ins2 & 0xFFC00000) == 0x91000000:  # add (imm12)
                rn = (ins2 >> 5) & 0x1F
                rd2 = ins2 & 0x1F
                imm12 = (ins2 >> 10) & 0xFFF
                if rn == rd:
                    va = base + imm12
                    if va in cands:
                        hits.append((pc, va, rd2))
                    break
            if (ins2 & 0x9F000000) == 0x90000000:
                break

    print(f'references: {len(hits)}')
    for pc, va, reg in hits:
        lo = max(vaddr, pc - window)
        hi = min(vaddr + vsize, pc + window)
        print(f'\n=== ref at 0x{pc:x} -> 0x{va:x} (x{reg}) ===')
        cmd = ['aarch64-linux-gnu-objdump', '-d', '--start-address', hex(lo),
               '--stop-address', hex(hi), '-b', 'binary', '-m', 'aarch64', path]
        # binary -b has no PE support, so use llvm-objdump if present
        try:
            out = subprocess.run(['llvm-objdump', '-d', '--arch-name=aarch64',
                                  f'--start-address=0x{lo:x}', f'--stop-address=0x{hi:x}', path],
                                 capture_output=True, text=True, check=True).stdout
        except Exception:
            out = subprocess.run(cmd, capture_output=True, text=True).stdout
        print(out)
    return 0


if __name__ == '__main__':
    sys.exit(main())
