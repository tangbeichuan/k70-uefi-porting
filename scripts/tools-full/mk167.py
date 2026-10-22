#!/usr/bin/env python3
"""mk167.py -- generate patch_usb167.py from patch_usb166.py.

keys167 = keys166 (SMMU bypass + vendor event-ring order + EP0 gadget) with the
EP0 responder aligned to the requested minimal bring-up profile:
  * device descriptor: VID 0x1209 / PID 0x0001, bcdUSB 0x0200, bcdDevice 0x0100,
    iManufacturer=1 / iProduct=2 / iSerialNumber=3, bNumConfigurations=1;
  * config descriptor: 1 vendor-specific interface, 0 endpoints (wTotalLength 18);
  * string 0 (en-US) + strings 1..3 ("Vermeer" / "K70 UEFI DEBUG" / "K70-0001");
  * SET_ADDRESS -> DCFG.DevAddr, SET_CONFIGURATION -> "[167] configured cfg=u",
    everything else -> SETSTALL;
  * "[167] setup bm=.. b=.. wv=.. wl=.. -> <action>" for the first 40 SETUPs;
  * "[167] ep0 armed" after arming the SETUP TRB;
  * raw event log raised to 40 events; done line gets setups=<count>.
"""
import pathlib
import sys

TOOLS = pathlib.Path("/mnt/d/本地项目-01/_tools")
src = (TOOLS / "patch_usb166.py").read_text(encoding="utf-8")

for old, new in (
    ("PATCH_USB166", "PATCH_USB167"),
    ("USB166", "USB167"),
    ("Usb166", "Usb167"),
    ("mTicks166", "mTicks167"),
    ("mShown166", "mShown167"),
    ("mGuiDisabled166", "mGuiDisabled167"),
    ("[166]", "[167]"),
    ("MENU166", "MENU167"),
    ("UI166", "UI167"),
    ("keys166", "keys167"),
    ("mk166.py", "mk167.py"),
    ("patch_usb166.py", "patch_usb167.py"),
):
    src = src.replace(old, new)

# ---- A) device descriptor: PID 0xC101 -> 0x0001 ------------------------------
OLD_DD = "  0x09, 0x12, 0x01, 0xC1, 0x00, 0x01, 1, 2, 3, 1"
NEW_DD = "  0x09, 0x12, 0x01, 0x00, 0x00, 0x01, 1, 2, 3, 1"
if OLD_DD not in src:
    print("mk167: FATAL device descriptor line not found")
    sys.exit(1)
src = src.replace(OLD_DD, NEW_DD)

# ---- B) strings: add serial string index 3 ----------------------------------
OLD_STR = '''STATIC CONST CHAR8  *mUsb167Strings[3] = {
  NULL, "Vermeer", "K70 UEFI DEBUG"
};'''
NEW_STR = '''STATIC CONST CHAR8  *mUsb167Strings[4] = {
  NULL, "Vermeer", "K70 UEFI DEBUG", "K70-0001"
};'''
if OLD_STR not in src:
    print("mk167: FATAL strings table not found")
    sys.exit(1)
src = src.replace(OLD_STR, NEW_STR)
if "  if (Index > 2) {\n    return 0;\n  }" not in src:
    print("mk167: FATAL string index bound not found")
    sys.exit(1)
src = src.replace("  if (Index > 2) {\n    return 0;\n  }",
                  "  if (Index > 3) {\n    return 0;\n  }")

# ---- C) action helper before Usb167Setup ------------------------------------
ACTION = '''STATIC CONST CHAR8 *
Usb167Action (
  IN UINT8   Type,
  IN UINT8   Req,
  IN UINT16  Value
  )
{
  if ((Type & 0x60) != 0) {
    return "class/vendor";
  }
  if (Req == 6) {
    switch ((UINT8)(Value >> 8)) {
    case 1:  return "desc-device";
    case 2:  return "desc-config";
    case 3:  return "desc-string";
    default: return "desc-other";
    }
  }
  if (Req == 5)  { return "set-address"; }
  if (Req == 9)  { return "set-config"; }
  if (Req == 8)  { return "get-config"; }
  if (Req == 0)  { return "get-status"; }
  if (Req == 11) { return "set-interface"; }
  return "unknown";
}

'''
ANCHOR = "STATIC VOID\nUsb167Setup (\n"
if ANCHOR not in src:
    print("mk167: FATAL Usb167Setup anchor not found")
    sys.exit(1)
src = src.replace(ANCHOR, ACTION + ANCHOR, 1)

# ---- D) setup log with action ----------------------------------------------
OLD_LOG = '''    Usb167Print (L"  [167] setup bm=%02x b=%02x wv=%04x wi=%04x wl=%04x",
                 Type, Req, Value,
                 (UINT16)(St[4] | (St[5] << 8)), Length);'''
NEW_LOG = '''    Usb167Print (L"  [167] setup bm=%02x b=%02x wv=%04x wl=%04x -> %a",
                 Type, Req, Value, Length, Usb167Action (Type, Req, Value));'''
if OLD_LOG not in src:
    print("mk167: FATAL setup log not found")
    sys.exit(1)
src = src.replace(OLD_LOG, NEW_LOG)

# ---- E) configured marker ---------------------------------------------------
OLD_CFG = 'Usb167Print (L"  [167] configured=%u", Value);'
NEW_CFG = 'Usb167Print (L"  [167] configured cfg=%u", Value);'
if OLD_CFG not in src:
    print("mk167: FATAL configured print not found")
    sys.exit(1)
src = src.replace(OLD_CFG, NEW_CFG)

# ---- F) done line gets setups count ----------------------------------------
OLD_DONE = '''    Usb167Line (L"  [167] done: evts=%u bytes=%u hlt22=%d DSTS=%08x",
                mUsb167Events, mUsb167Bytes,'''
NEW_DONE = '''    Usb167Line (L"  [167] done: evts=%u setups=%u hlt22=%d DSTS=%08x",
                mUsb167Events, mUsb167SetupCount,'''
if OLD_DONE not in src:
    print("mk167: FATAL done line not found")
    sys.exit(1)
src = src.replace(OLD_DONE, NEW_DONE)

# ---- G) raw event log 16 -> 40 ---------------------------------------------
if "if (mUsb167RawLogs < 16) {" not in src:
    print("mk167: FATAL raw log limit not found")
    sys.exit(1)
src = src.replace("if (mUsb167RawLogs < 16) {", "if (mUsb167RawLogs < 40) {")

# ---- H) ep0 armed marker ----------------------------------------------------
OLD_ARM = '''  mUsb167State = USB167_ST_SETUP;
  Usb167ArmSetup ();
  Dsts    = Usb167Rd (USB167_DSTS);'''
NEW_ARM = '''  mUsb167State = USB167_ST_SETUP;
  Usb167ArmSetup ();
  Usb167Print (L"  [167] ep0 armed (setup TRB queued, waiting for host SETUP)");
  Dsts    = Usb167Rd (USB167_DSTS);'''
if OLD_ARM not in src:
    print("mk167: FATAL armed anchor not found")
    sys.exit(1)
src = src.replace(OLD_ARM, NEW_ARM)

# ---- I) device event type print -------------------------------------------
OLD_DEV = "    Type = (Ev >> 8) & 0xF;"
NEW_DEV = '    Type = (Ev >> 8) & 0xF;\n    Usb167Print (L"  [167] dev evt type=%u", Type);'
if OLD_DEV not in src:
    print("mk167: FATAL device event anchor not found")
    sys.exit(1)
src = src.replace(OLD_DEV, NEW_DEV, 1)

# ---- J) sanity list additions ---------------------------------------------
OLD_NEED = '''for need in ("[MENU167]", "Usb167Init", "Usb167Poll", "Usb167Stat", "Usb167Clear",'''
NEW_NEED = '''for need in ("[MENU167]", "Usb167Init", "Usb167Poll", "Usb167Stat", "Usb167Clear",
             "Usb167Action", "[167] setup bm=", "[167] ep0 armed",
             "[167] configured cfg=", "[167] done: evts=", "K70-0001",'''
if OLD_NEED not in src:
    print("mk167: FATAL sanity anchor not found")
    sys.exit(1)
src = src.replace(OLD_NEED, NEW_NEED)

for bad in ("0xC1, 0x00", "configured=%u"):
    if bad in src:
        print("mk167: FATAL generated file still contains %r" % bad)
        sys.exit(1)

out = TOOLS / "patch_usb167.py"
out.write_text(src, encoding="utf-8")
print("mk167: wrote %s (%d bytes)" % (out, len(src)))
