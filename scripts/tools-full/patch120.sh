set +e
F=/mnt/d/本地项目-01/_k70port_extract/port-drivers/VermeerMenuDxe/VermeerMenuDxe.c
python3 - "$F" <<'PY'
import pathlib, sys
p = pathlib.Path(sys.argv[1]); s = p.read_text(encoding='utf-8', errors='surrogateescape')
if 'keys120' in s:
    print('already'); raise SystemExit
# 1) tweak footer wording
s = s.replace('GuiText ("VOL-UP / VOL-DOWN = move,  POWER = confirm"',
              'GuiText ("VOL-UP / VOL-DOWN = move   POWER/ENTER = select"', 1)
# 2) draw-status helper + action handling
helper = '''
// keys120: full-screen status page (drawn, not printed)
STATIC
VOID
GuiStatusPage (
  IN CONST CHAR8  *Title,
  IN CONST CHAR8  *Line1,
  IN CONST CHAR8  *Line2,
  IN CONST CHAR8  *Line3
  )
{
  GuiRect (0, 0, 1440, 3200, 0x00101820);
  GuiRect (0, 0, 1440, 170, 0x00003060);
  GuiRect (0, 170, 1440, 8, 0x000080C0);
  GuiText (Title, 60, 45, 4, 0x00FFFFFF, 0x00003060);
  GuiText (Line1, 60, 420, 3, 0x00E0F0FF, 0x00101820);
  GuiText (Line2, 60, 560, 3, 0x00E0F0FF, 0x00101820);
  GuiText (Line3, 60, 700, 3, 0x00E0F0FF, 0x00101820);
  GuiText ("press VOL-UP or VOL-DOWN to go back", 60, 900, 2, 0x0080A0B0, 0x00101820);
}

'''
anchor = 'STATIC\nVOID\nGuiMenu (\n  VOID\n  );'
if anchor in s:
    s = s.replace(anchor, anchor + '\n' + helper, 1)
else:
    s = s.replace('STATIC EFI_GRAPHICS_OUTPUT_PROTOCOL   *mGuiGop;',
                  'STATIC EFI_GRAPHICS_OUTPUT_PROTOCOL   *mGuiGop;\n' + helper, 1)
# 3) action dispatch inside confirm branch
s = s.replace('''            if (Selected == 3) {
              gRT->ResetSystem (EfiResetCold, EFI_SUCCESS, 0, NULL);
            } else if (Selected == 4) {
              gRT->ResetSystem (EfiResetShutdown, EFI_SUCCESS, 0, NULL);
            } else {
              PendingAct = 0;
              Redraw     = TRUE;
            }''',
'''            if (Selected == 3) {
              gRT->ResetSystem (EfiResetCold, EFI_SUCCESS, 0, NULL);
            } else if (Selected == 4) {
              gRT->ResetSystem (EfiResetShutdown, EFI_SUCCESS, 0, NULL);
            } else if (Selected == 0) {
              GuiStatusPage ("BOOT LINUX (UFS)", "no block device yet", "UFS is not initialised", "so no ESP to boot from");
              PendingAct = 0;
              WaitAnyKey ();
              Redraw = TRUE;
            } else if (Selected == 1) {
              GuiStatusPage ("BOOT UNIXNU", "\\\\EFI\\\\UniXNU\\\\unixnu.efi", "not found - there is no", "file system yet");
              PendingAct = 0;
              WaitAnyKey ();
              Redraw = TRUE;
            } else {
              GuiStatusPage ("DEVICE INFORMATION", "Vermeer / Redmi K70", "GOP 1440x3200 ready", "volume keys + power OK");
              PendingAct = 0;
              WaitAnyKey ();
              Redraw = TRUE;
            }''', 1)
# 4) WaitAnyKey helper before GuiMenu
waitfn = '''
STATIC
VOID
WaitAnyKey (
  VOID
  )
{
  EFI_INPUT_KEY Key;
  UINTN         I;
  UINTN         Tries = 0;
  EFI_HANDLE   *Hbuf  = NULL;
  UINTN         Hcnt  = 0;
  EFI_SIMPLE_TEXT_INPUT_PROTOCOL *Ins[8];
  UINTN         InsCount = 0;

  if (!EFI_ERROR (gBS->LocateHandleBuffer (ByProtocol, &gEfiSimpleTextInProtocolGuid, NULL, &Hcnt, &Hbuf))) {
    for (I = 0; I < Hcnt && InsCount < 8; I++) {
      VOID *Ifc = NULL;
      if (!EFI_ERROR (gBS->HandleProtocol (Hbuf[I], &gEfiSimpleTextInProtocolGuid, &Ifc)) && Ifc != NULL) {
        Ins[InsCount++] = (EFI_SIMPLE_TEXT_INPUT_PROTOCOL *)Ifc;
      }
    }
    gBS->FreePool (Hbuf);
  }
  while (Tries++ < 300) {            // up to ~6 s
    for (I = 0; I < InsCount; I++) {
      if (!EFI_ERROR (Ins[I]->ReadKeyStroke (Ins[I], &Key))) {
        return;
      }
    }
    gBS->Stall (20000);
  }
}

'''
anchor2 = 'STATIC\nVOID\nGuiMenu (\n  VOID\n  );'
s = s.replace(anchor2, waitfn + anchor2, 1)
p.write_text(s, encoding='utf-8', errors='surrogateescape')
print('keys120 applied')
PY
grep -n "keys120" "$F" | head -5