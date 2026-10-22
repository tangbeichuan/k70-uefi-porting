import io

P = '/mnt/d/本地项目-01/_k70port_extract/port-drivers/VermeerDtbExtnDxe/VermeerDtbExtnDxe.c'
s = io.open(P, encoding='utf-8', errors='replace').read()

offs = [0x08, 0x10, 0x18, 0x20, 0x28, 0x38, 0x40, 0x48, 0x50, 0x60, 0x68, 0x70,
        0x78, 0x80, 0x88, 0x90, 0x98, 0xa0, 0xb0, 0xb8, 0xc0, 0xd0, 0xd8, 0xe0,
        0xe8, 0xf0, 0xf8, 0x100]

stub_block = "//\n// keys59: 每个未实现槽位一个独立函数，打印自己的偏移 + 调用者 LR。\n//\n"
for o in offs:
    stub_block += (
        "STATIC EFI_STATUS\n"
        "EfiApi_Unsup_%03x (\n  VOID\n  )\n{\n"
        "  DEBUG ((\n"
        "    DEBUG_ERROR,\n"
        '    "[DTBEXTN] slot 0x%03x called, LR=0x%%lx\\n",\n'
        "    (UINT64)(UINTN)__builtin_return_address (0)\n"
        "    ));\n"
        "  return EFI_NOT_FOUND;\n"
        "}\n\n" % (o, o))

stub_block += "STATIC CONST struct {\n  UINTN    Off;\n  VOID     *Fn;\n} mStubTable[] = {\n"
for o in offs:
    stub_block += "  { 0x%03x, (VOID *)EfiApi_Unsup_%03x },\n" % (o, o)
stub_block += "};\n\n"

anchor = "//\n// The 0x108-byte interface."
assert anchor in s, 'interface anchor not found'
if 'mStubTable' not in s:
    s = s.replace(anchor, stub_block + anchor, 1)
    print('stub table inserted')

old_fill = """    for (Off = 0x08; Off < DTBEXTN_IFC_SIZE; Off += 8) {
      SetIfcSlot (Off, (VOID *)EfiApi_Unsupported);
    }"""
new_fill = """    for (Off = 0; Off < (sizeof (mStubTable) / sizeof (mStubTable[0])); Off++) {
      SetIfcSlot (mStubTable[Off].Off, mStubTable[Off].Fn);
    }
    if (FALSE) {
      SetIfcSlot (DTBEXTN_IFC_SIZE, (VOID *)EfiApi_Unsupported);
    }"""
if old_fill in s:
    s = s.replace(old_fill, new_fill, 1)
    print('fill loop replaced')
else:
    print('fill loop pattern not found')

io.open(P, 'w', encoding='utf-8').write(s)
print('written')
