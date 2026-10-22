set +e
F=/mnt/d/本地项目-01/_k70port_extract/port-drivers/VermeerMenuDxe/VermeerMenuDxe.c
I=/mnt/d/本地项目-01/_k70port_extract/port-drivers/VermeerMenuDxe/VermeerMenuDxe.inf
python3 - "$F" "$I" <<'PY'
import pathlib, sys
c = pathlib.Path(sys.argv[1]); i = pathlib.Path(sys.argv[2])
s = c.read_text(encoding='utf-8', errors='surrogateescape')
if 'keys115' in s:
    print('already patched'); raise SystemExit
# includes
s = s.replace('#include <Library/DebugLib.h>',
              '#include <Library/DebugLib.h>\n#include <Library/DxeServicesLib.h>   // keys115\n#include <Library/MemoryAllocationLib.h>  // keys115', 1)
# force-load SimpleFbDxe from FV, then report
probe = '''
STATIC CONST EFI_GUID mSimpleFbGuid = { 0xDCFD1E6D, 0x788D, 0x4FFC, { 0x8E, 0x1B, 0xCA, 0x2F, 0x75, 0x65, 0x1A, 0x92 } };  // keys115

STATIC
VOID
ForceLoadSimpleFb (
  VOID
  )
{
  VOID        *Blob  = NULL;
  UINTN        Size  = 0;
  EFI_HANDLE   NewHandle = NULL;
  EFI_STATUS   Status;
  CHAR16       Line2[128];

  Status = GetSectionFromAnyFv ((EFI_GUID *)&mSimpleFbGuid, EFI_SECTION_PE32, 0, &Blob, &Size);
  UnicodeSPrint (Line2, sizeof (Line2), L"  [UI] SimpleFb fv blob %r size=%lu\\r\\n", Status, (UINT64)Size);
  Say (Line2);
  if (EFI_ERROR (Status)) {
    return;
  }
  Status = gBS->LoadImage (FALSE, gImageHandle, NULL, Blob, Size, &NewHandle);
  UnicodeSPrint (Line2, sizeof (Line2), L"  [UI] SimpleFb LoadImage %r\\r\\n", Status);
  Say (Line2);
  if (EFI_ERROR (Status)) {
    return;
  }
  Status = gBS->StartImage (NewHandle, NULL, NULL);
  UnicodeSPrint (Line2, sizeof (Line2), L"  [UI] SimpleFb StartImage %r\\r\\n", Status);
  Say (Line2);
}

'''
anchor = 'STATIC\nVOID\nProbeGop ('
if anchor in s:
    s = s.replace(anchor, probe + anchor, 1)
else:
    s = s.replace('STATIC BOOLEAN  mGopPresent', probe + 'STATIC BOOLEAN  mGopPresent', 1)
# call it before first ProbeGop invocation
s = s.replace('  ProbeGop ();', '  ForceLoadSimpleFb ();  // keys115\n  ProbeGop ();', 1)
c.write_text(s, encoding='utf-8', errors='surrogateescape')
t = i.read_text(encoding='utf-8', errors='surrogateescape')
if 'DxeServicesLib' not in t:
    t = t.replace('  UefiLib\n', '  UefiLib\n  DxeServicesLib\n', 1)
    i.write_text(t, encoding='utf-8', errors='surrogateescape')
print('keys115 added')
PY
grep -n "keys115" "$F" | head -5
grep -n "DxeServicesLib" "$I"