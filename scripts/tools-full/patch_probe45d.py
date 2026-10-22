import pathlib

p = pathlib.Path('/mnt/d/本地项目-01/_k70port_extract/port-drivers/VermeerKeyProbeDxe/VermeerKeyProbeDxe.c')
s = p.read_text(errors='surrogateescape')

s = s.replace(
    '  UINTN         MapSize, MapKey, DescSize, DescVersion;',
    '  UINTN         MapSize, MapKey, DescSize;\n  UINT32        DescVersion;', 1)

p.write_text(s, errors='surrogateescape')
print('DescVersion is UINT32, the rest UINTN (matches UefiSpec.h)')
