set +e
F=/mnt/d/本地项目-01/_k70port_extract/port-drivers/VermeerMenuDxe/VermeerMenuDxe.c
python3 - "$F" <<'PY'
import pathlib, sys
p = pathlib.Path(sys.argv[1]); s = p.read_text(encoding='utf-8', errors='surrogateescape')
if 'keys116' in s:
    print('already patched'); raise SystemExit
# 1) load-once guard
s = s.replace('''STATIC
VOID
ForceLoadSimpleFb (
  VOID
  )
{
  VOID        *Blob  = NULL;''',
'''STATIC BOOLEAN mFbLoadTried = FALSE;   // keys116

STATIC
VOID
ForceLoadSimpleFb (
  VOID
  )
{
  VOID        *Blob  = NULL;''', 1)
s = s.replace('''  CHAR16       Line2[128];

  Status = GetSectionFromAnyFv''',
'''  CHAR16       Line2[128];

  if (mFbLoadTried) {   // keys116: never start it twice (Already started ASSERT)
    return;
  }
  mFbLoadTried = TRUE;

  Status = GetSectionFromAnyFv''', 1)
# 2) graphics banner helper + call
helper = '''
STATIC
VOID
FillRect (
  IN EFI_GRAPHICS_OUTPUT_PROTOCOL  *Gop,
  IN UINTN                          X,
  IN UINTN                          Y,
  IN UINTN                          W,
  IN UINTN                          H,
  IN UINT32                         Rgb
  )
{
  EFI_GRAPHICS_OUTPUT_BLT_PIXEL  Pixel;
  Pixel.Blue     = (UINT8)(Rgb & 0xFF);
  Pixel.Green    = (UINT8)((Rgb >> 8) & 0xFF);
  Pixel.Red      = (UINT8)((Rgb >> 16) & 0xFF);
  Pixel.Reserved = 0;
  Gop->Blt (Gop, &Pixel, EfiBltVideoFill, 0, 0, X, Y, W, H, 0);
}

STATIC
VOID
DrawBanner (
  VOID
  )
{
  EFI_GRAPHICS_OUTPUT_PROTOCOL  *Gop = NULL;
  CHAR16                         Line3[128];

  if (EFI_ERROR (gBS->LocateProtocol (&gEfiGraphicsOutputProtocolGuid, NULL, (VOID **)&Gop)) || Gop == NULL) {
    return;
  }
  // keys116: prove real pixel output (banner + right edge bar)
  FillRect (Gop, 0, 0, 1440, 140, 0x00204080);
  FillRect (Gop, 0, 140, 1440, 6, 0x0000C0FF);
  FillRect (Gop, 1400, 0, 40, 3200, 0x00404040);
  UnicodeSPrint (Line3, sizeof (Line3), L"  [UI] GFX banner drawn 1440x3200\\r\\n");
  Say (Line3);
}

'''
anchor = 'STATIC\nVOID\nForceLoadSimpleFb ('
s = s.replace(anchor, helper + anchor, 1)
# 3) draw banner once after GOP probe
s = s.replace('''      UnicodeSPrint (GopLine, sizeof (GopLine), L"  [UI] GOP=yes %ux%u\\r\\n", mGopW, mGopH);''',
'''      UnicodeSPrint (GopLine, sizeof (GopLine), L"  [UI] GOP=yes %ux%u\\r\\n", mGopW, mGopH);
      DrawBanner ();   // keys116''', 1)
p.write_text(s, encoding='utf-8', errors='surrogateescape')
print('keys116 applied')
PY
grep -n "keys116" "$F" | head -8