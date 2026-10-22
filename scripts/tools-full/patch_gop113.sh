set +e
F=/mnt/d/本地项目-01/_k70port_extract/port-drivers/VermeerMenuDxe/VermeerMenuDxe.c
python3 - "$F" <<'PY'
import pathlib, sys
p = pathlib.Path(sys.argv[1]); s = p.read_text(encoding='utf-8', errors='surrogateescape')
if 'keys113' in s:
    print('already patched'); raise SystemExit
anchor = '  Say (L"  [UI]  VOL-UP / VOL-DOWN to move, idle 3 s = act");'
if anchor not in s:
    print('anchor missing'); raise SystemExit(2)
# static GOP cache + probe function
helper = '''
STATIC BOOLEAN  mGopPresent = FALSE;   // keys113
STATIC UINT32   mGopW = 0;
STATIC UINT32   mGopH = 0;
STATIC BOOLEAN  mGopProbed  = FALSE;

STATIC
VOID
ProbeGop (
  VOID
  )
{
  EFI_GRAPHICS_OUTPUT_PROTOCOL  *Gop = NULL;
  if (mGopProbed) {
    return;
  }
  mGopProbed = TRUE;
  if (!EFI_ERROR (gBS->LocateProtocol (&gEfiGraphicsOutputProtocolGuid, NULL, (VOID **)&Gop)) &&
      Gop != NULL && Gop->Mode != NULL && Gop->Mode->Info != NULL) {
    mGopPresent = TRUE;
    mGopW       = (UINT32)Gop->Mode->Info->HorizontalResolution;
    mGopH       = (UINT32)Gop->Mode->Info->VerticalResolution;
  }
}

'''
marker = 'STATIC\nVOID\nSay ('
if marker in s:
    s = s.replace(marker, helper + marker, 1)
else:
    idx = s.find('Say (')
    s = s[:idx] + helper + s[idx:]
# print GOP in every header
ins = ('  ProbeGop ();\n'
       '  {\n'
       '    CHAR16  GopLine[96];\n'
       '    if (mGopPresent) {\n'
       '      UnicodeSPrint (GopLine, sizeof (GopLine), L"  [UI] GOP=yes %ux%u\\r\\n", mGopW, mGopH);\n'
       '    } else {\n'
       '      UnicodeSPrint (GopLine, sizeof (GopLine), L"  [UI] GOP=no\\r\\n");\n'
       '    }\n'
       '    Say (GopLine);\n'
       '  }\n'
       '  // keys113\n')
s = s.replace(anchor, ins + anchor, 1)
p.write_text(s, encoding='utf-8', errors='surrogateescape')
print('keys113 GOP header probe added')
PY
grep -n "keys113" "$F" | head -5