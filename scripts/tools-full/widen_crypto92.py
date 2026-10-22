import pathlib
f = pathlib.Path('/root/k70/uefi/Platforms/Xiaomi/vermeerPkg/Library/MemoryMapLib/MemoryMapLib.c')
s = f.read_text(encoding='utf-8', errors='surrogateescape')
old = '{"CRYPTO0 CRYPTO",      0x01DC0000, 0x00040000,'
if old not in s:
    # 宽容匹配：抓含 CRYPTO0 的那一行
    lines = s.splitlines(keepends=True)
    hit = [i for i,l in enumerate(lines) if 'CRYPTO0' in l]
    if not hit:
        print('CRYPTO0 not found'); raise SystemExit(1)
    new = '  {"CRYPTO0 CRYPTO",      0x01D80000, 0x00080000, AddDev, MMAP_IO, UNCACHEABLE, MmIO,   NS_DEVICE},\n'
    lines[hit[0]] = new
    f.write_text(''.join(lines), encoding='utf-8', errors='surrogateescape')
    print('CRYPTO0 widened to 0x01D80000+0x80000 (region count unchanged)')
else:
    s = s.replace(old, '{"CRYPTO0 CRYPTO",      0x01D80000, 0x00080000,')
    f.write_text(s, encoding='utf-8', errors='surrogateescape')
    print('CRYPTO0 widened (literal match)')