#!/usr/bin/env python3
"""patch_usb152.py -- keys152: replace the keys150 Menu block with a MINIMAL,
prints-only diagnostic Menu.

Target: /root/k70/uefi/Platforms/Xiaomi/vermeerPkg/Drivers/VermeerMenuDxe/VermeerMenuDxe.c
(the pkg copy, which patch_menu101.py has just refreshed from port-drivers)

Changes, in line with lead's m02933 request:
  1. Usb150LateDiag (writes PHYCFG / GCTL.PRTCAPDIR / DCTL.RUN_STOP, stalls,
     VBUS override)  ->  Usb152Diag : READ-ONLY dump only, no writes, no Stalls.
  2. entry: remove trailing CpuDeadLoop(); return EFI_SUCCESS instead.
  3. ForceLoadSimpleFb: drop GetSectionFromAnyFv / LoadImage / StartImage
     (no pulling our own GUI in); keep a single Say().
Idempotent via the "[MENU152]" marker.
"""
import pathlib
import sys

P = pathlib.Path("/root/k70/uefi/Platforms/Xiaomi/vermeerPkg/Drivers/VermeerMenuDxe/VermeerMenuDxe.c")
s = P.read_text(encoding="utf-8")

if "[MENU152]" in s:
    print("patch_usb152: already patched")
    sys.exit(0)

# --- sanity: we expect the keys150 block to be present ---------------------
if "[MENU150]" not in s or "Usb150LateDiag" not in s:
    print("patch_usb152: FATAL keys150 menu block not found")
    sys.exit(1)

NEW_FB = r'''STATIC
VOID
ForceLoadSimpleFb (
  VOID
  )
{
  //
  // keys152: SimpleFb LoadImage/StartImage intentionally disabled (prints-only
  // bisect build).  We do NOT want our own GUI driver pulled in from here.
  //
  if (mFbLoadTried) {
    return;
  }
  mFbLoadTried = TRUE;
  Say (L"  [UI152] SimpleFb load disabled (keys152)");
}

'''

NEW_DIAG = r'''STATIC VOID
Usb152Diag (
  VOID
  )
{
  CONST UINTN  Scratch = 0x0A6F8800;
  CHAR16       Buf[200];

  //
  // keys152: READ-ONLY diagnostic.  No writes to DWC3 / GCC / QSCRATCH, no
  // Stall-retry loop, no CpuDeadLoop.  If keys149 boots but this still hangs,
  // the print path itself is suspect; if this boots, one of the keys150 write
  // actions (PHYCFG clear / GCTL.PRTCAPDIR / DCTL.RUN_STOP) was the trigger.
  //
  Usb150Dump (L"pre ");
  UnicodeSPrint (Buf, sizeof (Buf),
                 L"  [USB152] vbus readonly: HS=%08x SS=%08x GCC_GDSCR=%08x",
                 Usb150Rd (Scratch + 0x10), Usb150Rd (Scratch + 0x30),
                 Usb150Rd (0x0010F004));
  Say (Buf);
  Usb150Dump (L"post");
}

'''

# --- 1) ForceLoadSimpleFb -> stub ------------------------------------------
a = s.find("STATIC\nVOID\nForceLoadSimpleFb (\n")
if a < 0:
    print("patch_usb152: FATAL ForceLoadSimpleFb not found")
    sys.exit(1)
b = s.find("STATIC\nVOID\nProbeGop (\n", a)
if b < 0:
    print("patch_usb152: FATAL ProbeGop not found")
    sys.exit(1)
s = s[:a] + NEW_FB + s[b:]

# --- 2) Usb150LateDiag -> Usb152Diag (read only) ---------------------------
a = s.find("STATIC VOID\nUsb150LateDiag (\n")
if a < 0:
    print("patch_usb152: FATAL Usb150LateDiag not found")
    sys.exit(1)
b = s.find("EFI_STATUS\nEFIAPI\nVermeerMenuDxeEntry", a)
if b < 0:
    print("patch_usb152: FATAL entry not found")
    sys.exit(1)
s = s[:a] + NEW_DIAG + s[b:]

# --- 2b) drop the now-unused Usb150Wr helper (-Wunused-function would fail) --
WR = ("STATIC VOID\nUsb150Wr (\n  IN UINTN   Address,\n  IN UINT32  Value\n  )\n{\n"
      "  *(volatile UINT32 *)Address = Value;\n}\n\n")
if WR not in s:
    print("patch_usb152: FATAL Usb150Wr block not found (exact whitespace)")
    sys.exit(1)
s = s.replace(WR, "", 1)

# --- 3) entry tail: no CpuDeadLoop, no GUI run ----------------------------
a = s.find('  Say (L"  [MENU150] console stays on, USB150 diag then photo halt");')
if a < 0:
    print("patch_usb152: FATAL MENU150 entry line not found")
    sys.exit(1)
b = s.find("  CpuDeadLoop ();", a)
if b < 0:
    print("patch_usb152: FATAL CpuDeadLoop not found")
    sys.exit(1)
b += len("  CpuDeadLoop ();")
NEW_TAIL = '''  Say (L"  [MENU152] minimal menu: read-only diag, no writes, returning to BDS");
  {
    STATIC UINTN  mGuiDisabled152 = 0;

    if (mGuiDisabled152 == 0) {
      Usb152Diag ();
    } else {
      RunMenu ();
    }
  }
  Say (L"  [MENU152] diag done - no CpuDeadLoop, returning");'''
s = s[:a] + NEW_TAIL + s[b:]

# --- sanity: no write helpers reachable from the diag path ----------------
for bad in ("Usb150Wr (Dwc3", "Usb150Wr (Scratch", "Usb150Wr (", "CpuDeadLoop ()"):
    if bad in s:
        print("patch_usb152: FATAL still contains %r" % bad)
        sys.exit(1)

P.write_text(s, encoding="utf-8")
print("patch_usb152: ForceLoadSimpleFb stubbed, Usb150LateDiag -> Usb152Diag (read-only), CpuDeadLoop removed")
print("PATCH_USB152 OK")
