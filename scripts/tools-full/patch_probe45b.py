import pathlib

p = pathlib.Path('/mnt/d/本地项目-01/_k70port_extract/port-drivers/VermeerKeyProbeDxe/VermeerKeyProbeDxe.c')
s = p.read_text(errors='surrogateescape')

# 1) GetMemoryMap wants UINT32 for key/desc-size/version on this tree
s = s.replace(
    '  UINTN         MapKey, MapSize, DescSize, DescVersion;',
    '  UINTN         MapSize;\n'
    '  UINT32        MapKey, DescSize, DescVersion;', 1)

# 2) drop the unused TextIns variable and its assignments
s = s.replace('    EFI_HANDLE    *List;\n    UINTN         TextIns;\n',
              '    EFI_HANDLE    *List;\n', 1)
s = s.replace('    TextIns = 0;\n    if (gST->ConIn != NULL) {\n      TextIns = 1;\n    }\n\n', '', 1)

# 3) escaped backslash inside the string literal
s = s.replace('needs an ESP with \\EFI\\UniXNU', 'needs an ESP with \\\\EFI\\\\UniXNU')

p.write_text(s, errors='surrogateescape')
print('patch45b applied')
