#!/usr/bin/env python3
"""mk168.py -- generate patch_usb168.py from patch_usb167.py.

keys168 = keys167 (EP0 responder, SMMU bypass, replug) with console landmarks:
  * no GOP full-screen fill, no ClearScreen: every landmark goes through
    ConOut (framebuffer console) followed by gBS->Stall(20 ms) so the last line
    before any fault is guaranteed to be visible;
  * ordered landmarks: "[168] menu entered" -> "[168] dma done" ->
    "[168] phy ready" -> "[168] smmu bypass done" -> "[168] evt ring set" ->
    "[168] ep armed" -> "[168] replug done" -> "[168] ep0 armed" ->
    "[168] init done" -> "[168] loop start";
  * every SETUP prints "[168] setup bm=.. b=.. wv=.. wl=.." (<=60 chars);
    SET_ADDRESS prints "[168] devaddr N";
  * never returns to BDS, never CpuDeadLoop: resident loop with
    "[168] alive evts=N" every 2 s, "[168] poll: cnt/DSTS/DCTL" via Stat(), and
    a replug retry (DCTL.RUN_STOP off/on, re-arm SETUP TRB) every 5 s so the
    host can re-enumerate whenever it wants.
"""
import pathlib
import sys

TOOLS = pathlib.Path("/mnt/d/本地项目-01/_tools")
src = (TOOLS / "patch_usb167.py").read_text(encoding="utf-8")


def must_replace(text, old, new, count=1, label=""):
    if text.count(old) < count:
        print("mk168: FATAL anchor not found (%s): %r" % (label, old[:70]))
        sys.exit(1)
    return text.replace(old, new, count)


for old, new in (
    ("PATCH_USB167", "PATCH_USB168"),
    ("USB167", "USB168"),
    ("Usb167", "Usb168"),
    ("mTicks167", "mTicks168"),
    ("mShown167", "mShown168"),
    ("mGuiDisabled167", "mGuiDisabled168"),
    ("[167]", "[168]"),
    ("MENU167", "MENU168"),
    ("keys167", "keys168"),
    ("patch_usb167.py", "patch_usb168.py"),
    ("mk167.py", "mk168.py"),
    ("patch_usb165", "patch_usb168"),
):
    src = src.replace(old, new)

# ---- 1) drop Usb168Line (no fixed-row drawing any more) ----------------------
a = src.find("STATIC VOID\nUsb168Line (\n")
b = src.find("STATIC VOID\nUsb168Clear (\n", a)
if a < 0 or b < 0:
    print("mk168: FATAL Line/Clear block not found")
    sys.exit(1)
src = src[:a] + src[b:]

# ---- 2) drop Usb168Clear (no screen clear; console must keep its history) ---
a = src.find("STATIC VOID\nUsb168Clear (\n")
b = src.find("STATIC VOID\nUsb168Print (\n", a)
if a < 0 or b < 0:
    print("mk168: FATAL Clear block not found")
    sys.exit(1)
src = src[:a] + src[b:]

# ---- 3) drop now-unused mUsb168Row and mShown-style globals -----------------
src = must_replace(src, "STATIC UINTN    mUsb168Row;\n", "", 1, "row global")

# ---- 4) insert the landmark printer right before Usb168Print -----------------
MARK = '''STATIC VOID
Usb168Mark (
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
  DEBUG ((DEBUG_ERROR, "%a\\n", Ascii));

  if (mOut != NULL) {
    mOut->OutputString (mOut, L"\\r\\n");
    mOut->OutputString (mOut, Buf);
  }
  gBS->Stall (20000);
}

'''
anchor = "STATIC VOID\nUsb168Print (\n"
src = must_replace(src, anchor, MARK + anchor, 1, "Print anchor")

# ---- 5) drop Usb168Action (action names no longer printed) -------------------
a = src.find("STATIC CONST CHAR8 *\nUsb168Action (\n")
b = src.find("STATIC VOID\nUsb168Setup (\n", a)
if a < 0 or b < 0:
    print("mk168: FATAL Action block not found")
    sys.exit(1)
src = src[:a] + src[b:]

# ---- 6) SETUP log -> short landmark ----------------------------------------
src = must_replace(
    src,
    '''    Usb168Print (L"  [168] setup bm=%02x b=%02x wv=%04x wl=%04x -> %a",
                 Type, Req, Value, Length, Usb168Action (Type, Req, Value));''',
    '''    Usb168Mark (L"[168] setup bm=%02x b=%02x wv=%04x wl=%04x",
                Type, Req, Value, Length);''',
    1, "setup log")

# ---- 7) SET_ADDRESS -> devaddr landmark ------------------------------------
src = must_replace(
    src,
    '    Usb168Print (L"  [168] address=%u", Value & 0x7F);',
    '    Usb168Mark (L"[168] devaddr %u", Value & 0x7F);',
    1, "set address log")

# ---- 8) init landmarks ------------------------------------------------------
src = must_replace(
    src,
    '''  Usb168Print (L"  [168] dma=%08x%08x (16 KiB)", (UINT32)(((UINT64)(UINTN)mUsb168Dma) >> 32),
               (UINT32)(UINTN)mUsb168Dma);''',
    '''  Usb168Print (L"  [168] dma=%08x%08x (16 KiB)", (UINT32)(((UINT64)(UINTN)mUsb168Dma) >> 32),
               (UINT32)(UINTN)mUsb168Dma);
  Usb168Mark (L"[168] dma done");''',
    1, "dma done")

src = must_replace(
    src,
    '''  Usb168Print (L"  [168] phycfg=%08x gctl=%08x dctl=%08x", Usb168Rd (USB168_GUSB2PHYCFG),
               Usb168Rd (USB168_GCTL), Usb168Rd (USB168_DCTL));''',
    '''  Usb168Print (L"  [168] phycfg=%08x gctl=%08x dctl=%08x", Usb168Rd (USB168_GUSB2PHYCFG),
               Usb168Rd (USB168_GCTL), Usb168Rd (USB168_DCTL));
  Usb168Mark (L"[168] phy ready");''',
    1, "phy ready")

src = must_replace(
    src,
    "  Usb168SmmuBypass ();\n",
    "  Usb168SmmuBypass ();\n  Usb168Mark (L\"[168] smmu bypass done\");\n",
    1, "smmu bypass done")

src = must_replace(
    src,
    '''  Usb168Print (L"  [168] evt: addr=%08x%08x siz=%08x cnt=%08x",
               Usb168Rd (USB168_GEVNTADRHI), Usb168Rd (USB168_GEVNTADRLO),
               Usb168Rd (USB168_GEVNTSIZ), Usb168Rd (USB168_GEVNTCOUNT));''',
    '''  Usb168Print (L"  [168] evt: addr=%08x%08x siz=%08x cnt=%08x",
               Usb168Rd (USB168_GEVNTADRHI), Usb168Rd (USB168_GEVNTADRLO),
               Usb168Rd (USB168_GEVNTSIZ), Usb168Rd (USB168_GEVNTCOUNT));
  Usb168Mark (L"[168] evt ring set");''',
    1, "evt ring set")

src = must_replace(
    src,
    "  Usb168Wr (USB168_DALEPENA, 0x3);\n",
    "  Usb168Wr (USB168_DALEPENA, 0x3);\n  Usb168Mark (L\"[168] ep armed\");\n",
    1, "ep armed")

src = must_replace(
    src,
    '''  Usb168Print (L"  [168] replug done: hlt22=%d DSTS=%08x DALEPENA=%08x",
               (Usb168Rd (USB168_DSTS) >> 22) & 1, Usb168Rd (USB168_DSTS),
               Usb168Rd (USB168_DALEPENA));''',
    '''  Usb168Print (L"  [168] replug done: hlt22=%d DSTS=%08x DALEPENA=%08x",
               (Usb168Rd (USB168_DSTS) >> 22) & 1, Usb168Rd (USB168_DSTS),
               Usb168Rd (USB168_DALEPENA));
  Usb168Mark (L"[168] replug done");''',
    1, "replug done")

src = must_replace(
    src,
    '  Usb168Print (L"  [168] ep0 armed (setup TRB queued, waiting for host SETUP)");',
    '''  Usb168Print (L"  [168] ep0 armed (setup TRB queued, waiting for host SETUP)");
  Usb168Mark (L"[168] ep0 armed");''',
    1, "ep0 armed")

src = must_replace(
    src,
    '''  Usb168Print (L"  [168] bringup done: hlt22=%d phycfg_bit6=%d devspd=%u evtaddr=%08x%08x",
               (Dsts >> 22) & 1, (Usb168Rd (USB168_GUSB2PHYCFG) >> 6) & 1, Dsts & 7,
               Usb168Rd (USB168_GEVNTADRHI), Usb168Rd (USB168_GEVNTADRLO));''',
    '''  Usb168Print (L"  [168] bringup done: hlt22=%d phycfg_bit6=%d devspd=%u evtaddr=%08x%08x",
               (Dsts >> 22) & 1, (Usb168Rd (USB168_GUSB2PHYCFG) >> 6) & 1, Dsts & 7,
               Usb168Rd (USB168_GEVNTADRHI), Usb168Rd (USB168_GEVNTADRLO));
  Usb168Mark (L"[168] init done");''',
    1, "init done")

# ---- 9) new resident tail (no clear, no halt, 2 s alive, 5 s replug) --------
NEW_TAIL = '''  Say (L"[MENU168] keys168 console landmarks, no clear, resident EP0 loop");
  Usb168Mark (L"[168] menu entered");
  {
    STATIC UINTN  mGuiDisabled168 = 0;
    STATIC UINTN  mTicks168       = 0;
    STATIC UINTN  mLastReplug168  = 0;

    Usb168Mark (L"[168] init start");
    Usb168Init ();
    Usb168Mark (L"[168] loop start");
    for (;;) {
      Usb168Poll ();
      if ((mTicks168 % 2000) == 0) {
        Usb168Stat ();
        Usb168Mark (L"[168] alive evts=%u", mUsb168Events);
      }
      if ((mTicks168 - mLastReplug168) >= 5000) {
        mLastReplug168 = mTicks168;
        Usb168Mark (L"[168] replug retry");
        Usb168Wr (USB168_DCTL, Usb168Rd (USB168_DCTL) & ~USB168_DCTL_RUN_STOP);
        gBS->Stall (150000);
        Usb168Wr (USB168_DCTL, Usb168Rd (USB168_DCTL) | USB168_DCTL_RUN_STOP);
        gBS->Stall (150000);
        mUsb168State = USB168_ST_SETUP;
        Usb168ArmSetup ();
      }
      if (mGuiDisabled168 == 0xFFFFFFFFU) {
        RunMenu ();
      }
      mTicks168++;
      gBS->Stall (1000);
    }
  }
'''
a = src.find("NEW_TAIL = '''")
b = src.find("'''\n\ns = s[:a] + NEW_TAIL + s[b:]", a)
if a < 0 or b < 0:
    print("mk168: FATAL NEW_TAIL block not found")
    sys.exit(1)
src = src[:a] + "NEW_TAIL = '''" + NEW_TAIL + src[b:]

# ---- 10) sanity section -----------------------------------------------------
a = src.find("# ---- sanity -----------------------------------------------------------------")
b = src.find("P.write_text", a)
if a < 0 or b < 0:
    print("mk168: FATAL sanity block not found")
    sys.exit(1)

SANITY = '''# ---- sanity -----------------------------------------------------------------
for bad in ("Usb150Wr (", "Usb150Rd (", "Usb150Dump (", "Usb150LateDiag",
            "0x0010F004", "0x0010F000", "0x0A6F8800",
            "Usb168Clear", "Usb168Line", "CpuDeadLoop ()"):
    if bad in s:
        print("patch_usb168: FATAL still contains %r" % bad)
        sys.exit(1)
for need in ("[MENU168]", "Usb168Init", "Usb168Poll", "Usb168Stat", "Usb168Mark",
             "[168] menu entered", "[168] init start", "[168] init done",
             "[168] dma done", "[168] phy ready", "[168] smmu bypass done",
             "[168] evt ring set", "[168] ep armed", "[168] ep0 armed",
             "[168] replug done", "[168] loop start", "[168] alive evts=",
             "[168] replug retry", "[168] setup bm=", "[168] devaddr",
             "K70-0001", "Usb168SmmuBypass", "smmu bypass", "smmu created",
             "AllocateMaxAddress", "0x1277", "GEVNTADRHI", "evtaddr=",
             "[168] replug: pull-up off", "[168] replug: pull-up on", "replug done",
             "RunMenu ()", "[168] evt raw=", "[168] dep evt raw=",
             "USB168_DEPCMD_STARTTRANSFER", "mUsb168CfgDesc", "K70 UEFI DEBUG"):
    if need not in s:
        print("patch_usb168: FATAL missing %r" % need)
        sys.exit(1)

'''
src = src[:a] + SANITY + src[b:]

src = must_replace(
    src,
    'print("patch_usb168: Menu -> DWC3 EP0 gadget + pull-up replug + raw event trace")',
    'print("patch_usb168: Menu -> console landmarks + resident EP0 loop (no clear, no halt)")',
    1, "final banner")

out = TOOLS / "patch_usb168.py"
out.write_text(src, encoding="utf-8")
print("mk168: wrote %s (%d bytes)" % (out, len(src)))
