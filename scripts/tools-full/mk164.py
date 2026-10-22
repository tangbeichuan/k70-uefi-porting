#!/usr/bin/env python3
"""mk164.py -- generate _tools/patch_usb164.py from _tools/patch_usb161.py.

keys164 = keys161 (EP0 gadget, NO CSFTRST, PHY kept alive) plus:
  * GOP screen clear + short "[164]" lines at the top of the screen;
  * FULL raw event trace: every event printed as "[164] evt raw=%08x"
    (no parsing), endpoint events additionally as "[164] dep evt raw=%08x",
    up to 16 events;
  * DEPCMD trace "[164] dep n=%u cmd=%02x ok=%u st=%x";
  * after ~8 s (or 16 events) print "[164] done: evts=.. bytes=.. hlt22=.. DSTS=.."
    then CpuDeadLoop() (screen freezes with the trace).
"""
import pathlib
import re

SRC = pathlib.Path("/mnt/d/本地项目-01/_tools/patch_usb161.py")
DST = pathlib.Path("/mnt/d/本地项目-01/_tools/patch_usb164.py")

s = SRC.read_text(encoding="utf-8")

# 1) rename 161 -> 164 everywhere (identifiers, markers, prints)
s = s.replace("161", "164")

# 2) extra bookkeeping variables
old = "STATIC UINT32   mUsb164RawLogs;\n"
assert s.count(old) == 1, "RawLogs anchor"
s = s.replace(old, old + "STATIC UINT32   mUsb164Bytes;\n", 1)
old = "STATIC UINT32   mUsb164LastDsts;\n"
assert s.count(old) == 1, "LastDsts anchor"
s = s.replace(old, "STATIC UINTN    mUsb164Row;\n" + old, 1)

# 3) short-line writer + GOP clear, inserted before Usb164Print
HELPERS = r'''STATIC VOID
Usb164Line (
  IN CONST CHAR16  *Format,
  ...
  )
{
  CHAR16   Buf[160];
  CHAR8    Ascii[160];
  VA_LIST  Marker;
  UINTN    Index;

  VA_START (Marker, Format);
  UnicodeVSPrint (Buf, sizeof (Buf), Format, Marker);
  VA_END (Marker);

  for (Index = 0; (Index < sizeof (Ascii) - 1) && (Buf[Index] != 0); Index++) {
    Ascii[Index] = (CHAR8)(Buf[Index] & 0xFF);
  }
  Ascii[Index] = 0;
  DEBUG ((DEBUG_ERROR, "%a\n", Ascii));

  if (mOut != NULL) {
    mOut->SetCursorPosition (mOut, 0, mUsb164Row);
    mOut->OutputString (mOut, Buf);
  }
  mUsb164Row++;
}

STATIC VOID
Usb164Clear (
  VOID
  )
{
  EFI_GRAPHICS_OUTPUT_PROTOCOL  *Gop = NULL;
  UINT32                        W;
  UINT32                        H;

  if (!EFI_ERROR (gBS->LocateProtocol (&gEfiGraphicsOutputProtocolGuid, NULL, (VOID **)&Gop)) &&
      (Gop != NULL) && (Gop->Mode != NULL) && (Gop->Mode->Info != NULL)) {
    W = (UINT32)Gop->Mode->Info->HorizontalResolution;
    H = (UINT32)Gop->Mode->Info->VerticalResolution;
    FillRect (Gop, 0, 0, W, H, 0x000000);
  } else if ((mOut != NULL) && (mOut->ClearScreen != NULL)) {
    mOut->ClearScreen (mOut);
  }

  if (mOut != NULL) {
    if (mOut->SetAttribute != NULL) {
      mOut->SetAttribute (mOut, EFI_TEXT_ATTR (EFI_LIGHTGRAY, EFI_BLACK));
    }
    mOut->SetCursorPosition (mOut, 0, 0);
  }
  mUsb164Row = 0;
}

'''
anchor = "STATIC VOID\nUsb164Print (\n"
assert s.count(anchor) == 1, "Usb164Print anchor"
s = s.replace(anchor, HELPERS + anchor, 1)

# 4) DEPCMD trace lines -> short [164] form
old = (
    '        Usb164Print (L"  [USB164] dep n=%u cmd=%02x ok=%u status=%x p0=%08x",\n'
    "                     Ep, Cmd & 0xF, (((Value >> 12) & 0xF) == 0) ? 1 : 0,\n"
    "                     (Value >> 12) & 0xF, Param0);\n"
)
new = (
    '        Usb164Print (L"  [164] dep n=%u cmd=%02x ok=%u st=%x",\n'
    "                     Ep, Cmd & 0xF, (((Value >> 12) & 0xF) == 0) ? 1 : 0,\n"
    "                     (Value >> 12) & 0xF);\n"
)
assert s.count(old) == 1, "dep log anchor"
s = s.replace(old, new, 1)

old = '    Usb164Print (L"  [USB164] dep n=%u cmd=%02x timeout p0=%08x", Ep, Cmd & 0xF, Param0);\n'
new = '    Usb164Print (L"  [164] dep n=%u cmd=%02x timeout", Ep, Cmd & 0xF);\n'
assert s.count(old) == 1, "dep timeout anchor"
s = s.replace(old, new, 1)

# 5) raw event trace: no parsing, 16 events, dep evt line for endpoint events
old = (
    "    if (mUsb164RawLogs < 8) {\n"
    "      mUsb164RawLogs++;\n"
    "      if ((Ev & 1) != 0) {\n"
    '        Usb164Print (L"  [USB164] evt raw=%08x type=%u ep=dev", Ev, (Ev >> 8) & 0xF);\n'
    "      } else {\n"
    '        Usb164Print (L"  [USB164] evt raw=%08x type=%u ep=%u", Ev, (Ev >> 6) & 0xF, (Ev >> 1) & 0x1F);\n'
    "      }\n"
    "    } else if (mUsb164Events <= 60) {\n"
    '      Usb164Print (L"  [USB164] evt=%08x", Ev);\n'
    "    }\n"
)
new = (
    "    if (mUsb164RawLogs < 16) {\n"
    "      mUsb164RawLogs++;\n"
    '      Usb164Print (L"  [164] evt raw=%08x", Ev);\n'
    "      if ((Ev & 1) == 0) {\n"
    '        Usb164Print (L"  [164] dep evt raw=%08x", Ev);\n'
    "      }\n"
    "    }\n"
)
assert s.count(old) == 1, "raw log anchor"
s = s.replace(old, new, 1)

old = "  Usb164Wr (USB164_GEVNTCOUNT, Count);   // write back to clear\n"
new = (
    "  Usb164Wr (USB164_GEVNTCOUNT, Count);   // write back consumed bytes\n"
    "  mUsb164Bytes += Count;\n"
)
assert s.count(old) == 1, "writeback anchor"
s = s.replace(old, new, 1)

# 6) compact Usb164Stat: one short poll line + one change line
a = s.find("STATIC VOID\nUsb164Stat (\n")
b = s.find("STATIC VOID\nUsb164Init (\n")
assert a >= 0 and b > a, "Usb164Stat anchors"
STAT = r'''STATIC VOID
Usb164Stat (
  VOID
  )
{
  UINT32  Dsts;
  UINT32  Count;

  Dsts  = Usb164Rd (USB164_DSTS);
  Count = Usb164Rd (USB164_GEVNTCOUNT) & 0xFFFF;
  Usb164Print (L"  [164] poll: cnt=%08x DSTS=%08x DCTL=%08x", Count, Dsts,
               Usb164Rd (USB164_DCTL));
  if ((Dsts != mUsb164LastDsts) || (Count != mUsb164LastCount)) {
    mUsb164LastDsts  = Dsts;
    mUsb164LastCount = Count;
    Usb164Print (L"  [164] regs: GCTL=%08x PHYCFG=%08x DEVTEN=%08x SIZ=%08x",
                 Usb164Rd (USB164_GCTL), Usb164Rd (USB164_GUSB2PHYCFG),
                 Usb164Rd (USB164_DEVTEN), Usb164Rd (USB164_GEVNTSIZ));
  }
}

'''
s = s[:a] + STAT + s[b:]

# 7) every remaining "[USB164]" print becomes "[164]"
s = s.replace('[USB164] ', '[164] ')

# 8) entry tail: clear screen, trace, 8 s / 16 events, done line, CpuDeadLoop
a = s.find("NEW_TAIL = '''")
b = s.find("'''\n\ns = s[:a] + NEW_TAIL", a)
assert a >= 0 and b > a, "NEW_TAIL anchors"
TAIL = """NEW_TAIL = '''  Usb164Clear ();
  Say (L"  [MENU164] keys164 EP0 trace: raw events only, 8 s then CpuDeadLoop");
  {
    STATIC UINTN  mGuiDisabled164 = 0;
    STATIC UINTN  mTicks164       = 0;
    STATIC UINTN  mShown164       = 0;

    Usb164Init ();
    for (;;) {
      Usb164Poll ();
      if ((mTicks164 % 1000) == 0) {
        if (mShown164 < 300) {
          mShown164++;
          Usb164Stat ();
        }
      }
      if (mUsb164Events >= 16) {
        break;
      }
      mTicks164++;
      if (mTicks164 >= 8000) {
        break;
      }
      gBS->Stall (1000);
    }
    Usb164Poll ();
    Usb164Line (L"  [164] done: evts=%u bytes=%u hlt22=%d DSTS=%08x",
                mUsb164Events, mUsb164Bytes,
                (Usb164Rd (USB164_DSTS) >> 22) & 1, Usb164Rd (USB164_DSTS));
    if (mGuiDisabled164 == 0xFFFFFFFFU) {
      RunMenu ();
    }
  }
  CpuDeadLoop ();"""
s = s[:a] + TAIL + s[b:]

# 9) sanity lists: keys164 intentionally contains CpuDeadLoop and needs the new bits
old_bad = 'for bad in ("Usb150Wr (", "Usb150Rd (", "Usb150Dump (", "Usb150LateDiag", "CpuDeadLoop ()",\n'
assert s.count(old_bad) == 1, "bad list anchor"
s = s.replace(old_bad, 'for bad in ("Usb150Wr (", "Usb150Rd (", "Usb150Dump (", "Usb150LateDiag",\n', 1)

old_need = 'for need in ("[MENU164]", "[USB164]", "Usb164Init", "Usb164Poll", "Usb164Stat", "RunMenu ()",\n             "USB164_DEPCMD_STARTTRANSFER", "mUsb164CfgDesc", "K70 UEFI DEBUG"):'
assert s.count(old_need) == 1, "need list anchor"
new_need = ('for need in ("[MENU164]", "Usb164Init", "Usb164Poll", "Usb164Stat", "Usb164Clear",\n'
            '             "Usb164Line", "RunMenu ()", "CpuDeadLoop ()", "[164] evt raw=",\n'
            '             "[164] dep evt raw=", "[164] done: evts=",\n'
            '             "USB164_DEPCMD_STARTTRANSFER", "mUsb164CfgDesc", "K70 UEFI DEBUG"):')
s = s.replace(old_need, new_need, 1)

# 10) docstring / final message
s = s.replace('"""patch_usb164.py -- keys164: minimal DWC3 device-mode EP0 gadget WITHOUT CSFTRST.',
              '"""patch_usb164.py -- keys164: EP0 gadget + screen clear + raw event trace + halt.\n\n'
              'Generated by mk164.py from patch_usb161.py.')

DST.write_text(s, encoding="utf-8")
print(f"wrote {DST} ({len(s)} bytes)")
print("marker check:", "[MENU164]" in s, "| CpuDeadLoop:", "CpuDeadLoop ()" in s,
      "| clear:", "Usb164Clear" in s, "| 8s loop:", "mTicks164 >= 8000" in s)
