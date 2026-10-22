#!/usr/bin/env python3
"""patch_usb157.py -- keys157: Menu becomes a READ-ONLY resident monitor.

Target: /root/k70/uefi/Platforms/Xiaomi/vermeerPkg/Drivers/VermeerMenuDxe/VermeerMenuDxe.c
(the pkg copy refreshed by patch_menu101.py from port-drivers each build)

keys154/keys156 did the DWC3 bring-up (PHYCFG clear + DCTL.RUN_STOP=1) inside
the Menu.  keys157 moves those writes into VermeerDtbExtnDxe (APRIORI position 4,
before every vendor USB driver) so the vendor gadget stack sees a running core.
The Menu therefore:

  1. never writes DWC3/QSCRATCH/GCC any more -- Usb157Dump() only *reads*;
  2. does not touch GCC at all (that MMIO window is unmapped in DXE: that is
     exactly what crashed keys152 at RVA 0x1C98 on 0x0010F004);
  3. stays in a resident loop (100 ms polls, key press to leave, alive dump
     every ~5 s) instead of returning to BDS; BDS would otherwise find no boot
     option and shut the phone down, closing the host enumeration window;
  4. keeps ForceLoadSimpleFb stubbed out (no LoadImage/StartImage from here).

Idempotent via the "[MENU157]" marker.
"""
import pathlib
import sys

P = pathlib.Path("/root/k70/uefi/Platforms/Xiaomi/vermeerPkg/Drivers/VermeerMenuDxe/VermeerMenuDxe.c")
s = P.read_text(encoding="utf-8")

if "[MENU157]" in s:
    print("patch_usb157: already patched")
    sys.exit(0)

if "[MENU150]" not in s or "Usb150LateDiag" not in s:
    print("patch_usb157: FATAL pristine keys150 menu block not found")
    sys.exit(1)

NEW_FB = r'''STATIC
VOID
ForceLoadSimpleFb (
  VOID
  )
{
  //
  // keys157: SimpleFb LoadImage/StartImage intentionally disabled.  We keep
  // the text UI only; pulling our own graphics driver in from the menu has
  // caused trouble before and is irrelevant to USB bring-up.
  //
  if (mFbLoadTried) {
    return;
  }
  mFbLoadTried = TRUE;
  Say (L"  [UI157] SimpleFb load disabled (keys157)");
}

'''

NEW_DIAG = r'''STATIC UINT32
Usb157Rd (
  IN UINTN  Address
  )
{
  return *(volatile UINT32 *)Address;
}

STATIC VOID
Usb157Dump (
  IN CONST CHAR16  *Tag
  )
{
  CONST UINTN  Dwc3    = 0x0A600000;
  CONST UINTN  Scratch = 0x0A6F8800;
  UINT32       Gsnpsid, Gctl, Dctl, Devten, Dsts, PhyCfg, Hs, Ss;
  CHAR16       Buf[220];

  //
  // keys157: READ-ONLY.  No writes to DWC3 / QSCRATCH / GCC.  The GCC window
  // is not mapped in the DXE page tables (that is exactly what crashed keys152
  // inside this Menu), so this function must never touch it.
  //
  Gsnpsid = Usb157Rd (Dwc3 + 0xC120);
  Gctl    = Usb157Rd (Dwc3 + 0xC110);
  PhyCfg  = Usb157Rd (Dwc3 + 0xC200);
  Dctl    = Usb157Rd (Dwc3 + 0xC704);
  Devten  = Usb157Rd (Dwc3 + 0xC708);
  Dsts    = Usb157Rd (Dwc3 + 0xC70C);
  Hs      = Usb157Rd (Scratch + 0x10);
  Ss      = Usb157Rd (Scratch + 0x30);

  UnicodeSPrint (Buf, sizeof (Buf),
                 L"  [USB157] %s: GSNPSID=%08x GCTL=%08x PHYCFG=%08x DCTL=%08x DEVTEN=%08x DSTS=%08x",
                 Tag, Gsnpsid, Gctl, PhyCfg, Dctl, Devten, Dsts);
  Say (Buf);
  UnicodeSPrint (Buf, sizeof (Buf),
                 L"  [USB157] %s: run=%d hlt22=%d spd=%u lnk=%u prtcap=%d HS=%08x SS=%08x",
                 Tag, (Dctl >> 31) & 1, (Dsts >> 22) & 1, Dsts & 7,
                 (Dsts >> 18) & 0xF, (Gctl >> 12) & 3, Hs, Ss);
  Say (Buf);
}

'''

c = s.find("STATIC\nVOID\nForceLoadSimpleFb (\n")
if c < 0:
    print("patch_usb157: FATAL ForceLoadSimpleFb not found")
    sys.exit(1)
d = s.find("STATIC\nVOID\nProbeGop (\n", c)
if d < 0:
    print("patch_usb157: FATAL ProbeGop not found")
    sys.exit(1)
s = s[:c] + NEW_FB + s[d:]

a = s.find("STATIC UINT32\nUsb150Rd (\n")
if a < 0:
    print("patch_usb157: FATAL Usb150Rd block not found")
    sys.exit(1)
b = s.find("EFI_STATUS\nEFIAPI\nVermeerMenuDxeEntry", a)
if b < 0:
    print("patch_usb157: FATAL entry not found")
    sys.exit(1)
s = s[:a] + NEW_DIAG + s[b:]

a = s.find('  Say (L"  [MENU150] console stays on, USB150 diag then photo halt");')
if a < 0:
    print("patch_usb157: FATAL MENU150 entry tail not found")
    sys.exit(1)
b = s.find("  CpuDeadLoop ();", a)
if b < 0:
    print("patch_usb157: FATAL CpuDeadLoop not found")
    sys.exit(1)
b += len("  CpuDeadLoop ();")

NEW_TAIL = '''  Say (L"  [MENU157] resident loop: USB device-mode already running early; staying enumerated");
  {
    STATIC UINTN  mGuiDisabled157 = 0;
    STATIC UINTN  mTicks157       = 0;
    EFI_INPUT_KEY Key;
    BOOLEAN       Got;

    Usb157Dump (L"entry");
    for (;;) {
      if ((mTicks157 % 50) == 0) {
        Usb157Dump (L"alive");
      }
      mTicks157++;
      Got = FALSE;
      if (mIn != NULL) {
        if (mIn->ReadKeyStroke (mIn, &Key) == EFI_SUCCESS) {
          Got = TRUE;
        }
      }
      if (Got) {
        break;
      }
      gBS->Stall (100000);
    }
    Say (L"  [MENU157] key pressed, leaving resident loop");
    if (mGuiDisabled157 == 0) {
      RunMenu ();
    }
  }
  Say (L"  [MENU157] done, returning to BDS");'''

s = s[:a] + NEW_TAIL + s[b:]

# ---- sanity: the Menu must not write USB/GCC any more -----------------------
for bad in ("Usb150Wr (", "Usb150Rd (", "Usb150Dump (", "Usb150LateDiag", "CpuDeadLoop ()",
            "0x0010F004", "0x0010F000"):
    if bad in s:
        print("patch_usb157: FATAL still contains %r" % bad)
        sys.exit(1)
for need in ("[MENU157]", "[USB157]", "ReadKeyStroke", "RunMenu ()"):
    if need not in s:
        print("patch_usb157: FATAL missing %r" % need)
        sys.exit(1)

P.write_text(s, encoding="utf-8")
print("patch_usb157: Menu -> read-only resident monitor (no USB/GCC writes, no CpuDeadLoop)")
print("PATCH_USB157 OK")
