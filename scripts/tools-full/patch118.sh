set +e
F=/mnt/d/本地项目-01/_k70port_extract/port-drivers/VermeerMenuDxe/VermeerMenuDxe.c
python3 - "$F" <<'PY'
import pathlib, sys
p = pathlib.Path(sys.argv[1]); s = p.read_text(encoding='utf-8', errors='surrogateescape')
if 'keys118' in s:
    print('already'); raise SystemExit
# 1) locals
s = s.replace('''  EFI_INPUT_KEY Key;
  BOOLEAN     Redraw = TRUE;

  if (mGuiGop == NULL) {
    return;
  }
''',
'''  EFI_INPUT_KEY Key;
  BOOLEAN     Redraw = TRUE;
  EFI_SIMPLE_TEXT_INPUT_PROTOCOL  *Ins[8];
  UINTN        InsCount = 0;
  UINTN        InsIdx;
  EFI_HANDLE  *Hbuf = NULL;
  UINTN        Hcnt = 0;

  if (mGuiGop == NULL) {
    return;
  }

  // keys118: enumerate ALL SimpleTextIn instances (gST->ConIn does not deliver on this board)
  if (!EFI_ERROR (gBS->LocateHandleBuffer (ByProtocol, &gEfiSimpleTextInProtocolGuid, NULL, &Hcnt, &Hbuf))) {
    for (InsIdx = 0; InsIdx < Hcnt && InsCount < 8; InsIdx++) {
      VOID  *Ifc = NULL;
      if (!EFI_ERROR (gBS->HandleProtocol (Hbuf[InsIdx], &gEfiSimpleTextInProtocolGuid, &Ifc)) && Ifc != NULL) {
        Ins[InsCount++] = (EFI_SIMPLE_TEXT_INPUT_PROTOCOL *)Ifc;
      }
    }
    gBS->FreePool (Hbuf);
  }
''', 1)
# 2) replace read block
s = s.replace('''    if (gST->ConIn != NULL) {
      Status = gST->ConIn->ReadKeyStroke (gST->ConIn, &Key);
      if (!EFI_ERROR (Status)) {''',
'''    {
      Status = EFI_NOT_READY;
      for (InsIdx = 0; InsIdx < InsCount; InsIdx++) {
        if (!EFI_ERROR (Ins[InsIdx]->ReadKeyStroke (Ins[InsIdx], &Key))) {
          Status = EFI_SUCCESS;
          break;
        }
      }
      if (!EFI_ERROR (Status)) {''', 1)
p.write_text(s, encoding='utf-8', errors='surrogateescape')
print('keys118 key fix applied')
PY
grep -n "keys118" "$F" | head -4