import pathlib
p = pathlib.Path('/mnt/d/本地项目-01/_k70port_extract/port-drivers/VermeerKeyProbeDxe/VermeerKeyProbeDxe.c')
s = p.read_text(encoding='utf-8')
if 'STATIC VOID Say (' not in s.split('LaunchEmbeddedApp')[0]:
    s = s.replace('STATIC CONST EFI_GUID mStage2AppGuid = {',
                  'STATIC VOID Say (CONST CHAR8 *Text);\n\nSTATIC CONST EFI_GUID mStage2AppGuid = {', 1)
p.write_text(s, encoding='utf-8')
print('added Say forward declaration')