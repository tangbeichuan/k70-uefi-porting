import pathlib

p = pathlib.Path('/mnt/d/本地项目-01/_k70port_extract/port-drivers/VermeerKeyProbeDxe/VermeerKeyProbeDxe.c')
s = p.read_text(errors='surrogateescape')

s = s.replace(
    '  UINTN         MapSize;\n  UINT32        MapKey, DescSize, DescVersion;',
    '  UINTN         MapSize, MapKey, DescSize, DescVersion;', 1)

p.write_text(s, errors='surrogateescape')
print('GetMemoryMap parameter types fixed (all UINTN in this tree)')
