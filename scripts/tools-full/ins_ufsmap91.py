import pathlib, sys
f = pathlib.Path('/root/k70/uefi/Platforms/Xiaomi/vermeerPkg/Library/MemoryMapLib/MemoryMapLib.c')
s = f.read_text(encoding='utf-8', errors='surrogateescape')
if '0x01D80000' in s or '0x01d80000' in s:
    print('UFS entry already present')
else:
    anchor = '  {"CORE_TOP_CSR",'
    if anchor not in s:
        anchor = '  // Register Regions'
    ins = '  {"UFS",                0x01D80000, 0x00020000, AddDev, MMAP_IO, UNCACHEABLE, MmIO,   NS_DEVICE},\n'
    s = s.replace(anchor, ins + anchor, 1)
    f.write_text(s, encoding='utf-8', errors='surrogateescape')
    print('UFS entry inserted before CORE_TOP_CSR')