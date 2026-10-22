#!/usr/bin/env python3
import glob, hashlib, pathlib

FFS = glob.glob('/root/k70/uefi/Build/vermeerPkg/DEBUG_CLANGPDB/FV/Ffs/5776232E*PmicDxe/*.ffs')
print('ffs:', FFS)
if not FFS:
    raise SystemExit('no ffs')
data = pathlib.Path(FFS[0]).read_bytes()
print('ffs size', len(data))
print('ffs sha256', hashlib.sha256(data).hexdigest())

cands = {
    'stock   ': '/root/k70/uefi/Binaries/vermeer/QcomPkg/Drivers/PmicDxe/PmicDxeLa.efi',
    'patched ': '/root/k70/uefi/Binaries/vermeer/QcomPkg/Drivers/PmicDxe/PmicDxeLa.patched.efi',
}
for label, p in cands.items():
    b = pathlib.Path(p).read_bytes()
    off = data.find(b)
    print(label, 'size', len(b), 'sha', hashlib.sha256(b).hexdigest()[:16], 'found_in_ffs_at', off)
    if off >= 0:
        # show the three patch sites inside the embedded image
        for rva, what in ((0x3ffc, 'bl->nop#1'), (0x4004, 'bl->nop#2'), (0x14744, 'check->mov w0,#0')):
            print('   ', hex(rva), what, data[off + rva: off + rva + 8].hex())
print('--- final FD / img ---')
for p in ('/mnt/d/本地项目-01/_k70port_extract/qemu-fw/SILICIUM_UEFI-keys140.fd',
          '/mnt/d/本地项目-01/K70-UEFI-build/Mu-vermeer-keys140.img'):
    b = pathlib.Path(p).read_bytes()
    print(p, len(b), hashlib.sha256(b).hexdigest())
    vendor = pathlib.Path(cands['stock   ']).read_bytes()
    print('   stock PmicDxeLa bytes present in image:', b.find(vendor))
