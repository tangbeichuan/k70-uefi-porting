#!/usr/bin/env python3
# pmic_13_str.py : print printable strings found at/after given file offsets
import sys

data = open('/tmp/pmic/pmic.bin', 'rb').read() if False else None
# read the efi itself
efi = open('/root/k70/uefi/Binaries/vermeer/QcomPkg/Drivers/PmicDxe/PmicDxeLa.efi', 'rb').read()

def show(off, maxlen=200):
    end = off
    while end < len(efi) and end - off < maxlen and 32 <= efi[end] < 127:
        end += 1
    raw = efi[off:end]
    try:
        s = raw.decode('ascii')
    except Exception:
        s = repr(raw)
    print('0x%06x (len %d): %r' % (off, end - off, s))

for a in sys.argv[1:]:
    show(int(a, 16))
