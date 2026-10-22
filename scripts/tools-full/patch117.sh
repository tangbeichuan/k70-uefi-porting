set +e
F=/mnt/d/本地项目-01/_k70port_extract/port-drivers/VermeerMenuDxe/VermeerMenuDxe.c
python3 - "$F" <<'PY'
import pathlib, sys
p = pathlib.Path(sys.argv[1]); s = p.read_text(encoding='utf-8', errors='surrogateescape')
if 'keys117' in s:
    print('already patched'); raise SystemExit

font = pathlib.Path('/mnt/d/本地项目-01/_tools/font8x16.h').read_text(encoding='utf-8')
font = font.replace('#pragma once\n#include <Uefi.h>\n', '')

gui = font + '''
// ============================ keys117: graphical menu ============================
STATIC EFI_GRAPHICS_OUTPUT_PROTOCOL   *mGuiGop = NULL;
STATIC EFI_GRAPHICS_OUTPUT_BLT_PIXEL   mGuiPixel;
STATIC EFI_GRAPHICS_OUTPUT_BLT_PIXEL   mGuiBuf[32 * 16];

STATIC
EFI_GRAPHICS_OUTPUT_BLT_PIXEL
Rgb (
  IN UINT32  Color
  )
{
  EFI_GRAPHICS_OUTPUT_BLT_PIXEL  P;
  P.Blue     = (UINT8)(Color & 0xFF);
  P.Green    = (UINT8)((Color >> 8) & 0xFF);
  P.Red      = (UINT8)((Color >> 16) & 0xFF);
  P.Reserved = 0;
  return P;
}

STATIC
VOID
GuiRect (
  IN UINTN   X,
  IN UINTN   Y,
  IN UINTN   W,
  IN UINTN   H,
  IN UINT32  Color
  )
{
  mGuiPixel = Rgb (Color);
  mGuiGop->Blt (mGuiGop, &mGuiPixel, EfiBltVideoFill, 0, 0, X, Y, W, H, 0);
}

STATIC
VOID
GuiGlyph (
  IN CHAR8   Ch,
  IN UINTN   X,
  IN UINTN   Y,
  IN UINTN   Scale,
  IN UINT32  Fg,
  IN UINT32  Bg
  )
{
  CONST UINT8  *Bits;
  UINTN         Row;
  UINTN         Col;
  UINTN         Dx;
  UINTN         Dy;
  UINTN         W;
  UINTN         H;

  if (Ch < 32 || Ch > 126) {
    Ch = '?';
  }
  Bits = mFont8x16[(UINT8)Ch - 32];
  W    = 8 * Scale;
  H    = 16 * Scale;
  for (Row = 0; Row < 16; Row++) {
    for (Col = 0; Col < 8; Col++) {
      BOOLEAN On = (BOOLEAN)((Bits[Row] >> (7 - Col)) & 1);
      EFI_GRAPHICS_OUTPUT_BLT_PIXEL Px = Rgb (On ? Fg : Bg);
      for (Dy = 0; Dy < Scale; Dy++) {
        for (Dx = 0; Dx < Scale; Dx++) {
          mGuiBuf[(Row * Scale + Dy) * W + (Col * Scale + Dx)] = Px;
        }
      }
    }
  }
  mGuiGop->Blt (mGuiGop, mGuiBuf, EfiBltBufferToVideo, 0, 0, X, Y, W, H, 0);
}

STATIC
VOID
GuiText (
  IN CONST CHAR8  *Text,
  IN UINTN         X,
  IN UINTN         Y,
  IN UINTN         Scale,
  IN UINT32        Fg,
  IN UINT32        Bg
  )
{
  UINTN  I;
  for (I = 0; Text[I] != 0; I++) {
    GuiGlyph (Text[I], X + I * 8 * Scale, Y, Scale, Fg, Bg);
  }
}

STATIC
VOID
GuiMenu (
  VOID
  )
{
  static CONST CHAR8 *Items[5] = {
    "Boot Linux (UFS)",
    "Boot UniXNU",
    "Device information",
    "Reboot",
    "Power off"
  };
  UINTN       Selected = 0;
  UINTN       Index;
  UINTN       Y;
  EFI_STATUS  Status;
  EFI_INPUT_KEY Key;
  BOOLEAN     Redraw = TRUE;

  if (mGuiGop == NULL) {
    return;
  }

  while (TRUE) {
    if (Redraw) {
      GuiRect (0, 0, 1440, 3200, 0x00101820);
      GuiRect (0, 0, 1440, 170, 0x00003060);
      GuiRect (0, 170, 1440, 8, 0x000080C0);
      GuiText ("VERMEER UEFI", 60, 40, 5, 0x00FFFFFF, 0x00003060);
      GuiText ("Project Silicium  /  Redmi K70", 60, 130, 2, 0x00A0C8E0, 0x00003060);

      Y = 420;
      for (Index = 0; Index < 5; Index++) {
        if (Index == Selected) {
          GuiRect (60, Y - 18, 1320, 110, 0x00004080);
          GuiRect (60, Y - 18, 14, 110, 0x0000C0FF);
          GuiText (Items[Index], 110, Y, 4, 0x00FFFFFF, 0x00004080);
        } else {
          GuiText (Items[Index], 110, Y, 4, 0x00C8D8E8, 0x00101820);
        }
        Y += 150;
      }

      GuiText ("VOL-UP / VOL-DOWN = move", 60, 1320, 2, 0x0080A0B0, 0x00101820);
      GuiText ("idle 3 s = act            POWER = off", 60, 1370, 2, 0x0080A0B0, 0x00101820);

      if (Status == EFI_SUCCESS) { /* keep compiler quiet */ }
      Redraw = FALSE;
    }

    if (gST->ConIn != NULL) {
      Status = gST->ConIn->ReadKeyStroke (gST->ConIn, &Key);
      if (!EFI_ERROR (Status)) {
        if (Key.ScanCode == 0x01) {
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
        }
      }
    }
    gBS->Stall (20000);
  }
}
'''

anchor = 'EFI_STATUS\nEFIAPI\nVermeerMenuDxeEntry'
idx = s.find(anchor)
if idx < 0:
    print('entry anchor not found'); raise SystemExit(2)
s = s[:idx] + gui + '\n' + s[idx:]
# call GuiMenu at the end of entry instead of text menu loop
s = s.replace('  ProbeGop ();', '  ProbeGop ();\n  if (mGopPresent) {\n    mGuiGop = NULL;\n    gBS->LocateProtocol (&gEfiGraphicsOutputProtocolGuid, NULL, (VOID **)&mGuiGop);\n    if (mGuiGop != NULL) {\n      GuiMenu ();   // keys117: never returns\n    }\n  }', 1)
p.write_text(s, encoding='utf-8', errors='surrogateescape')
print('keys117 GUI menu installed')
PY
grep -c "keys117" "$F"