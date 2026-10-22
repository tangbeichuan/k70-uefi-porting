#!/usr/bin/env python3
"""patch_usb152b.py -- keys152b: prints-only Menu, NO USB dump at all.

Baseline: the pkg copy of VermeerMenuDxe.c right after patch_menu101.py has
refreshed it from port-drivers (i.e. pristine keys149 menu with the keys150
USB block).  This patch makes the absolutely minimal Menu:

  * ForceLoadSimpleFb  -> stub with a single Say() (no LoadImage/StartImage)
  * delete the whole keys150 USB block (Usb150Rd/Usb150Wr/Usb150Dump/
    Usb150LateDiag) - no register reads, no writes
  * entry tail          -> two [MENU152] Say() lines + RunMenu() reference,
                           no diag, no CpuDeadLoop, return EFI_SUCCESS

Purpose (lead, m03120): if keys154 still faults in Menu, keys152b proves
whether the register dump itself (not any write) is what breaks.
Idempotent via the "[MENU152B]" marker.
"""
import pathlib
import sys

P = pathlib.Path("/root/k70/uefi/Platforms/Xiaomi/vermeerPkg/Drivers/VermeerMenuDxe/VermeerMenuDxe.c")
s = P.read_text(encoding="utf-8")

if "[MENU152B]" in s:
    print("patch_usb152b: already patched")
    sys.exit(0)

if "Usb150LateDiag" not in s:
    print("patch_usb152b: FATAL baseline is not the pristine keys149 menu (Usb150LateDiag missing)")
    sys.exit(1)

NEW_FB = r'''STATIC
VOID
ForceLoadSimpleFb (
  VOID
  )
{
  //
  // keys152b: SimpleFb LoadImage/StartImage intentionally disabled.
  //
  if (mFbLoadTried) {
    return;
  }
  mFbLoadTried = TRUE;
  Say (L"  [UI152B] SimpleFb load disabled (keys152b)");
}

'''

# --- 1) ForceLoadSimpleFb -> stub ------------------------------------------
a = s.find("STATIC\nVOID\nForceLoadSimpleFb (\n")
if a < 0:
    print("patch_usb152b: FATAL ForceLoadSimpleFb not found")
    sys.exit(1)
b = s.find("STATIC\nVOID\nProbeGop (\n", a)
if b < 0:
    print("patch_usb152b: FATAL ProbeGop not found")
    sys.exit(1)
s = s[:a] + NEW_FB + s[b:]

# --- 2) drop the entire keys150 USB block ----------------------------------
a = s.find("STATIC UINT32\nUsb150Rd (\n")
if a < 0:
    print("patch_usb152b: FATAL Usb150Rd not found")
    sys.exit(1)
b = s.find("EFI_STATUS\nEFIAPI\nVermeerMenuDxeEntry", a)
if b < 0:
    print("patch_usb152b: FATAL entry not found")
    sys.exit(1)
s = s[:a] + s[b:]

# --- 3) entry tail: two Say lines only, keep RunMenu alive ----------------
a = s.find('  Say (L"  [MENU150] console stays on, USB150 diag then photo halt");')
if a < 0:
    print("patch_usb152b: FATAL MENU150 entry line not found")
    sys.exit(1)
b = s.find("  CpuDeadLoop ();", a)
if b < 0:
    print("patch_usb152b: FATAL CpuDeadLoop not found")
    sys.exit(1)
b += len("  CpuDeadLoop ();")
NEW_TAIL = '''  Say (L"  [MENU152B] prints-only menu: no USB diag, no writes, returning to BDS");
  {
    STATIC UINTN  mGuiDisabled152B = 0;

    if (mGuiDisabled152B != 0) {
      RunMenu ();
    }
  }
  Say (L"  [MENU152B] done, returning to BDS");'''
s = s[:a] + NEW_TAIL + s[b:]

# --- sanity ---------------------------------------------------------------
for bad in ("Usb150Rd", "Usb150Wr", "Usb150Dump", "Usb150LateDiag",
            "CpuDeadLoop ()", "0x0A600000", "0x0A6F8800"):
    if bad in s:
        print("patch_usb152b: FATAL still contains %r" % bad)
        sys.exit(1)

P.write_text(s, encoding="utf-8")
print("PATCH_USB152B OK: prints-only menu, keys150 USB block removed")
