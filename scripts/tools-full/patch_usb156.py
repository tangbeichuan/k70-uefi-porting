#!/usr/bin/env python3
"""patch_usb156.py -- keys154 -> keys156 Menu patch (alive check only).

Baseline = keys154 Menu (Usb154Run: PHYCFG clear + DCTL RUN_STOP=1 + Stall 50ms x2,
verified on hardware: dctl 10F00000 -> 30F00000, hlt22=0, spd=4, lnk=5).

keys156 adds ONLY:
  1. Say "[USB156] menu returned, waiting for BDS"
  2. gBS->Stall (3000000)   # 3 s
  3. Say "[USB156] still alive after 3s"
placed right after the keys154 bring-up block, before the function returns.
No other behaviour changes: PHYCFG/DCTL write order and parameters untouched,
no QSCRATCH write, no new module, no PEI change.
Idempotent: skips when "[USB156]" is already present.
"""
import pathlib
import sys

P = pathlib.Path("/root/k70/uefi/Platforms/Xiaomi/vermeerPkg/Drivers/VermeerMenuDxe/VermeerMenuDxe.c")
s = P.read_text(encoding="utf-8")

if "[USB156]" in s:
    print("patch_usb156: already patched ([USB156] present)")
    sys.exit(0)

if "Usb154Run" not in s or "[MENU154]" not in s:
    print("patch_usb156: FATAL baseline is not keys154 (Usb154Run/[MENU154] missing)")
    sys.exit(1)

anchor = """  {
    STATIC UINTN  mGuiDisabled154 = 0;

    if (mGuiDisabled154 == 0) {
      Usb154Run ();
    } else {
      RunMenu ();
    }
  }
"""
if anchor not in s:
    print("patch_usb156: FATAL keys154 entry tail anchor not found")
    sys.exit(1)

tail = """
  Say (L"  [USB156] menu returned, waiting for BDS");
  gBS->Stall (3000000);
  Say (L"  [USB156] still alive after 3s");
"""
s = s.replace(anchor, anchor + tail, 1)

if "gBS->Stall" not in s:
    print("patch_usb156: FATAL gBS->Stall not available in menu source")
    sys.exit(1)

P.write_text(s, encoding="utf-8")
print("PATCH_USB156 OK: two [USB156] markers + gBS->Stall(3s) added after keys154 bring-up")
