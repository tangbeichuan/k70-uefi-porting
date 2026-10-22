set +e
F=/mnt/d/本地项目-01/_k70port_extract/port-drivers/VermeerMenuDxe/VermeerMenuDxe.c
python3 - "$F" <<'PY'
import pathlib, sys
p = pathlib.Path(sys.argv[1]); s = p.read_text(encoding='utf-8', errors='surrogateescape')
if 'keys119' in s:
    print('already'); raise SystemExit
# locals for last key + confirm
s = s.replace('''  EFI_HANDLE  *Hbuf = NULL;
  UINTN        Hcnt = 0;''',
'''  EFI_HANDLE  *Hbuf = NULL;
  UINTN        Hcnt = 0;
  CHAR8        KeyLine[64];          // keys119
  UINTN        PendingAct = 0;       // keys119: selection awaiting confirm
  UINTN        ConfirmTicks = 0;     // keys119''', 1)
# status line after footer
s = s.replace('''      GuiText ("idle 3 s = act            POWER = off", 60, 1370, 2, 0x0080A0B0, 0x00101820);''',
'''      GuiText ("VOL-UP / VOL-DOWN = move,  POWER = confirm", 60, 1370, 2, 0x0080A0B0, 0x00101820);
      // keys119: live key status + confirm hint
      AsciiSPrint (KeyLine, sizeof (KeyLine), "last key: scan=0x%02x uni=0x%04x   %a",
                   LastScan, LastUni, (PendingAct != 0) ? "PRESS POWER AGAIN TO CONFIRM" : "");
      GuiText (KeyLine, 60, 1460, 2, 0x00FFD070, 0x00101820);''', 1)
# key handling with power-as-confirm
s = s.replace('''        if (Key.ScanCode == 0x01) {
          Selected = (Selected + 4) % 5;
          Redraw   = TRUE;
        } else if (Key.ScanCode == 0x02) {
          Selected = (Selected + 1) % 5;
          Redraw   = TRUE;
        } else {
          // keys117: act on selection (no ENTER on this device)
          if (Selected == 3) {
            gRT->ResetSystem (EfiResetCold, EFI_SUCCESS, 0, NULL);
          } else if (Selected == 4) {
            gRT->ResetSystem (EfiResetShutdown, EFI_SUCCESS, 0, NULL);
          }
        }''',
'''        LastScan = Key.ScanCode;   // keys119
        LastUni  = Key.UnicodeChar;
        if (Key.ScanCode == 0x01) {
          Selected = (Selected + 4) % 5;
          PendingAct = 0;
          Redraw   = TRUE;
        } else if (Key.ScanCode == 0x02) {
          Selected = (Selected + 1) % 5;
          PendingAct = 0;
          Redraw   = TRUE;
        } else {
          // keys119: any non-navigation key (power button / others) = confirm
          if (PendingAct != Selected) {
            PendingAct   = Selected + 1;   // store +1 so 0 means "none"
            ConfirmTicks = 0;
            Redraw       = TRUE;
          } else {
            if (Selected == 3) {
              gRT->ResetSystem (EfiResetCold, EFI_SUCCESS, 0, NULL);
            } else if (Selected == 4) {
              gRT->ResetSystem (EfiResetShutdown, EFI_SUCCESS, 0, NULL);
            } else {
              PendingAct = 0;
              Redraw     = TRUE;
            }
          }
        }''', 1)
# declare LastScan/LastUni + confirm timeout decay
s = s.replace('''  CHAR8        KeyLine[64];          // keys119''',
'''  CHAR8        KeyLine[64];          // keys119
  UINTN        LastScan = 0xFFFF;    // keys119
  UINTN        LastUni  = 0xFFFF;    // keys119''', 1)
s = s.replace('''    gBS->Stall (20000);''',
'''    gBS->Stall (20000);
    if (PendingAct != 0) {           // keys119: confirm window ~3 s
      ConfirmTicks++;
      if (ConfirmTicks > 150) {
        PendingAct = 0;
        Redraw     = TRUE;
      }
    }''', 1)
p.write_text(s, encoding='utf-8', errors='surrogateescape')
print('keys119 applied')
PY
grep -n "keys119" "$F" | head -6