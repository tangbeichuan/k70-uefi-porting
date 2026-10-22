import pathlib
f = pathlib.Path('/root/k70/uefi/Platforms/Xiaomi/vermeerPkg/Library/MemoryMapLib/MemoryMapLib.c')
s = f.read_text(encoding='utf-8', errors='surrogateescape')
added = []
if '0x01D80000' not in s and '0x01d80000' not in s:
    anchor = '  {"CRYPTO0 CRYPTO",'
    if anchor not in s:
        anchor = '  // Register Regions'
    ins = '  {"UFS",                0x01D80000, 0x00020000, AddDev, MMAP_IO, UNCACHEABLE, MmIO,   NS_DEVICE},\n'
    s = s.replace(anchor, ins + anchor, 1); added.append('UFS')
if '0x00100000ULL' not in s and '"GCC"' not in s:
    anchor2 = '  {"UFS",'
    if anchor2 not in s:
        anchor2 = '  // Register Regions'
    ins2 = '  {"GCC",                0x00100000, 0x00200000, AddDev, MMAP_IO, UNCACHEABLE, MmIO,   NS_DEVICE},\n'
    s = s.replace(anchor2, ins2 + anchor2, 1); added.append('GCC')
f.write_text(s, encoding='utf-8', errors='surrogateescape')
print('memmap entries added:', added)