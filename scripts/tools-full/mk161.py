#!/usr/bin/env python3
"""mk161.py -- generate patch_usb161.py (keys161: EP0 gadget WITHOUT DCTL.CSFTRST)
and patch_usb161b.py (keys161b: minimal-write variant) from patch_usb160.py.

keys161  : no soft reset at all; clear PHYCFG (SUSPHY/ENBLSLPM/PHYSOFTRST) + 20 ms,
           guarantee DCTL.CSFTRST==0 without pulsing it, RUN_STOP retried 3x
           (off/on toggle) if the core reports halted, arm SETUP TRB after RUN.
keys161b : same but PHYCFG clears only SUSPHY/ENBLSLPM (bit6/bit8) and DCTL is left
           completely untouched when the controller already reports run=1/hlt22=0.
"""
import pathlib

TOOLS = pathlib.Path(__file__).resolve().parent
SRC = TOOLS / "patch_usb160.py"


def sub(s, old, new, tag):
    n = s.count(old)
    if n != 1:
        raise SystemExit(f"{tag}: expected 1 occurrence, got {n}")
    return s.replace(old, new, 1)


s = SRC.read_text(encoding="utf-8")
s = s.replace("160", "161")

# ---- header / wording ------------------------------------------------------
s = sub(s,
        '"""patch_usb161.py -- keys161: Menu hosts a MINIMAL DWC3 device-mode EP0 gadget.',
        '"""patch_usb161.py -- keys161: minimal DWC3 device-mode EP0 gadget WITHOUT CSFTRST.',
        "header")
s = sub(s,
        "  * DWC3 device soft reset (DCTL.CSFTRST, poll self-clear);",
        "  * NO device soft reset (DCTL.CSFTRST removed: it resets the PHY/clocks domain);",
        "header2")

# ---- 1) replace soft reset + PHY re-clear with no-reset bring-up -----------
old_csftrst = """  //
  // 1) Device soft reset (PHY / clocks stay as XBL-BL left them).
  //
  Usb161Wr (USB161_DCTL, USB161_DCTL_CSFTRST);
  for (I = 0; (I < 500) && ((Usb161Rd (USB161_DCTL) & USB161_DCTL_CSFTRST) != 0); I++) {
    gBS->Stall (1000);
  }
  Usb161Print (L"  [USB161] soft reset done after %u ms DCTL=%08x GCTL=%08x",
               (UINT32)I, Usb161Rd (USB161_DCTL), Usb161Rd (USB161_GCTL));
  if ((Usb161Rd (USB161_DCTL) & USB161_DCTL_CSFTRST) != 0) {
    Say (L"  [USB161] FATAL: soft reset stuck");
    return;
  }

  //
  // 1b) CSFTRST restores the PHY-suspend defaults: clear SUSPHY / ENBLSLPM / PHYSOFTRST
  //     again and give the PHY 20 ms to settle before touching endpoints.
  //
  Usb161Wr (USB161_GUSB2PHYCFG, Usb161Rd (USB161_GUSB2PHYCFG) & ~USB161_PHYCFG_CLEAR);
  gBS->Stall (20000);
  Usb161Print (L"  [USB161] phycfg=%08x gctl=%08x", Usb161Rd (USB161_GUSB2PHYCFG),
               Usb161Rd (USB161_GCTL));
"""
new_phy = """  //
  // 1) NO device soft reset in keys161: DCTL.CSFTRST soft-resets the PHY/clocks domain
  //    on this SoC and has been observed to kill the upstream connection entirely.
  //    Only clear PHY suspend / suspend-on-sleep / PHY soft-reset and let it settle.
  //
  Usb161Wr (USB161_GUSB2PHYCFG, Usb161Rd (USB161_GUSB2PHYCFG) & ~USB161_PHYCFG_CLEAR);
  gBS->Stall (20000);

  //
  // 1b) Guarantee DCTL.CSFTRST stays 0 WITHOUT pulsing it (a read-modify-write that
  //     only clears bit30 never triggers the reset).
  //
  if ((Usb161Rd (USB161_DCTL) & USB161_DCTL_CSFTRST) != 0) {
    Usb161Wr (USB161_DCTL, Usb161Rd (USB161_DCTL) & ~USB161_DCTL_CSFTRST);
    gBS->Stall (1000);
  }
  Usb161Print (L"  [USB161] phycfg=%08x gctl=%08x dctl=%08x", Usb161Rd (USB161_GUSB2PHYCFG),
               Usb161Rd (USB161_GCTL), Usb161Rd (USB161_DCTL));
"""
s = sub(s, old_csftrst, new_phy, "csftrst")

# ---- 2) declare the retry tick variable -----------------------------------
s = sub(s,
        "  UINTN                 I;\n  UINT32                Gsnpsid;",
        "  UINTN                 I;\n  UINTN                 Ticks;\n  UINT32                Gsnpsid;",
        "ticks")

# ---- 3) replace RUN block with 3x RUN_STOP toggle retry -------------------
old_run = """  //
  // 5) Run first, then arm the SETUP TRB once the controller reports not-halted
  //    (Linux dwc3 arms ep0 transfers only after the core is running).
  //
  Usb161Wr (USB161_DCTL, Usb161Rd (USB161_DCTL) | USB161_DCTL_RUN_STOP);
  for (I = 0; (I < 500) && ((Usb161Rd (USB161_DSTS) & USB161_DSTS_DEVCTRLHLT) != 0); I++) {
    gBS->Stall (1000);
  }
"""
new_run = """  //
  // 5) Run: if the core is halted, toggle RUN_STOP off/on (up to 3 attempts, never
  //    touching CSFTRST), then arm the SETUP TRB once DSTS reports not-halted.
  //
  for (I = 0; I < 3; I++) {
    if ((Usb161Rd (USB161_DSTS) & USB161_DSTS_DEVCTRLHLT) == 0) {
      break;
    }
    Usb161Wr (USB161_DCTL, Usb161Rd (USB161_DCTL) & ~USB161_DCTL_RUN_STOP);
    gBS->Stall (1000);
    Usb161Wr (USB161_DCTL, Usb161Rd (USB161_DCTL) | USB161_DCTL_RUN_STOP);
    for (Ticks = 0; Ticks < 200; Ticks++) {
      if ((Usb161Rd (USB161_DSTS) & USB161_DSTS_DEVCTRLHLT) == 0) {
        break;
      }
      gBS->Stall (1000);
    }
  }
"""
s = sub(s, old_run, new_run, "run")

# ---- 4) bringup-done line + widened 1 s poll line -------------------------
old_up2 = """  Usb161Print (L"  [USB161] up2: DALEPENA=%08x DSTS=%08x hlt22=%d spd=%u",
               Usb161Rd (USB161_DALEPENA), Dsts, (Dsts >> 22) & 1, Dsts & 7);
"""
new_up2 = """  Usb161Print (L"  [USB161] up2: DALEPENA=%08x DSTS=%08x hlt22=%d spd=%u",
               Usb161Rd (USB161_DALEPENA), Dsts, (Dsts >> 22) & 1, Dsts & 7);
  Usb161Print (L"  [USB161] bringup done: hlt22=%d phycfg_bit6=%d devspd=%u",
               (Dsts >> 22) & 1, (Usb161Rd (USB161_GUSB2PHYCFG) >> 6) & 1, Dsts & 7);
"""
s = sub(s, old_up2, new_up2, "up2")

old_poll = """  Usb161Print (L"  [USB161] poll: DSTS=%08x hlt22=%d spd=%u evtcnt=%08x",
               Dsts, (Dsts >> 22) & 1, Dsts & 7, Count);
"""
new_poll = """  Usb161Print (L"  [USB161] poll: DCTL=%08x DSTS=%08x PHYCFG=%08x SIZ=%08x",
               Usb161Rd (USB161_DCTL), Dsts, Usb161Rd (USB161_GUSB2PHYCFG),
               Usb161Rd (USB161_GEVNTSIZ));
  Usb161Print (L"  [USB161] poll2: hlt22=%d spd=%u devspd=%u cnt=%08x",
               (Dsts >> 22) & 1, Dsts & 7, Dcfg & 7, Count);
"""
s = sub(s, old_poll, new_poll, "poll")

out = TOOLS / "patch_usb161.py"
out.write_text(s, encoding="utf-8", newline="\n")
print("wrote", out, len(s), "chars")

# ===========================================================================
# keys161b: minimal-write variant
# ===========================================================================
t = s.replace("161", "161b")
# tag strings: USB161B / MENU161B are fine (sed 161->161b on names)
t = t.replace('"""patch_usb161b.py',
              '"""patch_usb161b.py (keys161b: minimal-write variant)')

minimal_phy = """  //
  // 1) MINIMAL-WRITE variant: only clear PHY suspend (SUSPHY bit6) and
  //    suspend-on-sleep (ENBLSLPM bit8); PHYSOFTRST is left as-is.
  //
  Usb161bWr (USB161b_GUSB2PHYCFG, Usb161bRd (USB161b_GUSB2PHYCFG) & ~USB161b_PHYCFG_CLEAR);
  gBS->Stall (20000);
  Usb161bPrint (L"  [USB161b] phycfg=%08x gctl=%08x dctl=%08x", Usb161bRd (USB161b_GUSB2PHYCFG),
                Usb161bRd (USB161b_GCTL), Usb161bRd (USB161b_DCTL));
"""
t = sub(t, new_phy.replace("161", "161b"), minimal_phy, "161b-phy")

minimal_run = """  //
  // 5) MINIMAL-WRITE variant: if the controller already reports run=1 / hlt22=0,
  //    do NOT touch DCTL at all.  Only when it is halted, toggle RUN_STOP off/on
  //    (up to 3 attempts, never touching CSFTRST).
  //
  if (((Usb161bRd (USB161b_DCTL) & USB161b_DCTL_RUN_STOP) != 0) &&
      ((Usb161bRd (USB161b_DSTS) & USB161b_DSTS_DEVCTRLHLT) == 0)) {
    Say (L"  [USB161b] dctl untouched (already running)");
  } else {
    for (I = 0; I < 3; I++) {
      if ((Usb161bRd (USB161b_DSTS) & USB161b_DSTS_DEVCTRLHLT) == 0) {
        break;
      }
      Usb161bWr (USB161b_DCTL, Usb161bRd (USB161b_DCTL) & ~USB161b_DCTL_RUN_STOP);
      gBS->Stall (1000);
      Usb161bWr (USB161b_DCTL, Usb161bRd (USB161b_DCTL) | USB161b_DCTL_RUN_STOP);
      for (Ticks = 0; Ticks < 200; Ticks++) {
        if ((Usb161bRd (USB161b_DSTS) & USB161b_DSTS_DEVCTRLHLT) == 0) {
          break;
        }
        gBS->Stall (1000);
      }
    }
  }
"""
t = sub(t, new_run.replace("161", "161b"), minimal_run, "161b-run")

# PHYCFG clear mask: SUSPHY(bit6) | ENBLSLPM(bit8) only
t = sub(t,
        "#define USB161b_PHYCFG_CLEAR    ((1U << 31) | (1U << 8) | (1U << 6))",
        "#define USB161b_PHYCFG_CLEAR    ((1U << 8) | (1U << 6))",
        "161b-mask")

outb = TOOLS / "patch_usb161b.py"
outb.write_text(t, encoding="utf-8", newline="\n")
print("wrote", outb, len(t), "chars")
