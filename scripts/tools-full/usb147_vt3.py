import re, sys

ASM = '/tmp/ucfg_vt.asm'
lines = open(ASM, encoding='utf-8', errors='replace').read().splitlines()
pat = re.compile(r'^\s*([0-9a-f]+):\s')

def dump(title, lo, hi):
    print('===== %s (0x%x-0x%x) =====' % (title, lo, hi))
    for ln in lines:
        m = pat.match(ln)
        if not m:
            continue
        v = int(m.group(1), 16)
        if lo <= v <= hi:
            print(ln)

dump('iface methods +0x08..+0x40 (0x1460-0x1560)', 0x1460, 0x1562)
dump('iface methods +0x50..+0x78 (0x1560-0x1660)', 0x1562, 0x1664)
dump('iface+0x80 method 0x169c-0x1714', 0x169C, 0x1714)
dump('iface+0x98..+0xb0 0x1714-0x1740', 0x1714, 0x1740)
dump('DWC3 struct builder 0x8850-0x88a0', 0x8850, 0x88A0)
dump('GCTL reader 0x8d80-0x8e50', 0x8D80, 0x8E50)
dump('role/status 0xa140-0xa200', 0xA140, 0xA200)
dump('DSTS/GCTL users 0xa380-0xa4e0', 0xA380, 0xA4E0)
