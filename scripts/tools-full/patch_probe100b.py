import pathlib
p = pathlib.Path('/mnt/d/本地项目-01/_k70port_extract/port-drivers/VermeerKeyProbeDxe/VermeerKeyProbeDxe.c')
s = p.read_text(encoding='utf-8')

# include
if 'DxeServicesLib.h' not in s:
    s = s.replace('#include <Uefi.h>', '#include <Uefi.h>\n#include <Library/DxeServicesLib.h>', 1)

# 去掉之前写坏的 helper（如果存在）
start = s.find('//\n// keys100:')
if start >= 0:
    end = s.find('STATIC UINTN  mSkipUfsTest = 1;', start)
    if end > start:
        s = s[:start] + s[end:]

helper = r'''
//
// keys100: 把内嵌在 FV 里的 EFI 应用（VermeerStage2App, FILE_GUID 2C9A63D4-...）
// 取出来用 LoadImage()/StartImage() 跑起来。这是「固件 -> EFI 应用」握手，
// 也是将来启动真正 UniXNU.efi 的同一条路。
//
STATIC CONST EFI_GUID mStage2AppGuid = {
  0x2c9a63d4, 0x8b17, 0x4e52, { 0xa6, 0xf1, 0x9d, 0x0c, 0x7b, 0x3e, 0x5a, 0x48 }
};

STATIC
VOID
LaunchEmbeddedApp (
  VOID
  )
{
  EFI_STATUS  Status;
  VOID        *Blob;
  UINTN       Size;
  EFI_HANDLE  NewHandle;
  CHAR8       Msg[128];

  Blob      = NULL;
  Size      = 0;
  NewHandle = NULL;

  Status = GetSectionFromAnyFv ((EFI_GUID *)&mStage2AppGuid, EFI_SECTION_PE32, 0, &Blob, &Size);
  AsciiSPrint (Msg, sizeof (Msg), "[STAGE2] fv blob=0x%lx size=%ld -> %r\n",
               (UINT64)(UINTN)Blob, (UINT64)Size, Status);
  Say (Msg);
  if (EFI_ERROR (Status) || (Blob == NULL)) {
    return;
  }

  Status = gBS->LoadImage (FALSE, gImageHandle, NULL, Blob, Size, &NewHandle);
  AsciiSPrint (Msg, sizeof (Msg), "[STAGE2] LoadImage -> %r\n", Status);
  Say (Msg);
  if (EFI_ERROR (Status)) {
    return;
  }

  Status = gBS->StartImage (NewHandle, NULL, NULL);
  AsciiSPrint (Msg, sizeof (Msg), "[STAGE2] StartImage -> %r (app returned)\n", Status);
  Say (Msg);
}

'''

anchor = 'STATIC UINTN  mSkipUfsTest = 1;'
assert anchor in s
s = s.replace(anchor, helper + anchor, 1)

old = '    LaunchEmbeddedApp ();\n'
if old not in s:
    old2 = '    Say ("  [UI] menu skipped (keys99) - dispatch continues\\n");\n    return EFI_SUCCESS;'
    new2 = '    Say ("  [UI] menu skipped (keys99) - dispatch continues\\n");\n    LaunchEmbeddedApp ();\n    return EFI_SUCCESS;'
    assert old2 in s, 'menu block not found'
    s = s.replace(old2, new2, 1)

p.write_text(s, encoding='utf-8')
print('probe patched cleanly')