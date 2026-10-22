#!/usr/bin/env python3
"""patch_usb155.py -- keys152 -> keys155 Menu: READ-ONLY GCC/clock diagnostics.

Why: keys152 crashed reading GCC_USB30_PRIM_GDSCR (0x0010F004) because the GCC
region is not mapped in the DXE page tables.  keys155 first adds the GCC region
to the PEI memory map (patch_gcc155.py), then this Menu only READS:

  * DWC3 GCTL/GUSB2PHYCFG/DCTL/DSTS with full bit decode (Dwc3.h semantics)
  * GCC_USB30_PRIM_GDSCR (0x0F004, bit31 = power on)
  * GCC USB30_PRIM CBCRs (0x0F010 master / 0x0F014 sleep / 0x0F018 utmi,
    bit31 = CLK_OFF) + cfg-noc-axi / aggre-axi / ahb2phy / clkref
  * GCC 0x0F084 (USB3 PHY GDSCR candidate) and 0x0F000 (BCR candidate)
  * GCC USB30_PRIM block scan 0x0F000..0x0F0FF (to expose the BCR offsets)
  * QSCRATCH +0x10/+0x30 read-only

NO writes at all: no DCTL.RUN_STOP, no GCTL, no PHYCFG, no QSCRATCH, no GCC.
Idempotent via the "Usb155Diag" marker.
"""
import pathlib
import sys

P = pathlib.Path("/root/k70/uefi/Platforms/Xiaomi/vermeerPkg/Drivers/VermeerMenuDxe/VermeerMenuDxe.c")
s = P.read_text(encoding="utf-8")

if "Usb155Diag" in s:
    print("patch_usb155: already patched")
    sys.exit(0)

if "Usb152Diag" not in s:
    print("patch_usb155: FATAL baseline is not keys152 (Usb152Diag missing)")
    sys.exit(1)

NEW_DIAG = r'''STATIC VOID
Usb155Diag (
  VOID
  )
{
  CONST UINTN  Dwc3    = 0x0A600000;
  CONST UINTN  Gcc     = 0x00100000;
  CONST UINTN  Scratch = 0x0A6F8800;
  UINT32       Gctl;
  UINT32       PhyCfg;
  UINT32       Dctl;
  UINT32       Dsts;
  UINT32       Gdscr;
  UINT32       CbM;
  UINT32       CbS;
  UINT32       CbU;
  UINT32       GdscrPhy;
  UINT32       Bcr;
  UINT32       Hs;
  UINT32       Ss;
  UINTN        N;
  UINTN        O;
  CHAR16       Buf[240];

  //
  // keys155: STRICTLY READ-ONLY.  The GCC region (0x00100000, 2 MiB) is now in
  // the PEI memory map, so GCC_GDSCR/CBCR reads are legal in DXE.  keys152
  // crashed at Menu +0x1C98 on exactly this read because GCC was unmapped.
  // Nothing is written: no DCTL.RUN_STOP, no PHYCFG, no GCTL, no QSCRATCH.
  //
  Usb150Dump (L"pre ");

  Gctl   = Usb150Rd (Dwc3 + 0xC110);
  PhyCfg = Usb150Rd (Dwc3 + 0xC200);
  Dctl   = Usb150Rd (Dwc3 + 0xC704);
  Dsts   = Usb150Rd (Dwc3 + 0xC70C);

  UnicodeSPrint (Buf, sizeof (Buf),
                 L"  [USB155] gctl=%08x prtcap=%d pwrdnscale=%d refclk=%d bit9=%d coresoftrst=%d clk_gating_dis=%d",
                 Gctl, (Gctl >> 12) & 3, (Gctl >> 19) & 0xF, Gctl & 3,
                 (Gctl >> 9) & 1, (Gctl >> 11) & 1, Gctl & 1);
  Say (Buf);
  UnicodeSPrint (Buf, sizeof (Buf),
                 L"  [USB155] phycfg=%08x susphy=%d enblslpm=%d physoftrst=%d usbtrdtim=%d",
                 PhyCfg, (PhyCfg >> 6) & 1, (PhyCfg >> 8) & 1,
                 (PhyCfg >> 31) & 1, (PhyCfg >> 10) & 0xF);
  Say (Buf);
  UnicodeSPrint (Buf, sizeof (Buf),
                 L"  [USB155] dctl=%08x run_stop=%d csfrst=%d hird=%d css=%d keep_connect=%d",
                 Dctl, (Dctl >> 31) & 1, (Dctl >> 30) & 1, (Dctl >> 24) & 0x1F,
                 (Dctl >> 16) & 1, (Dctl >> 19) & 1);
  Say (Buf);
  UnicodeSPrint (Buf, sizeof (Buf),
                 L"  [USB155] dsts=%08x hlt22=%d coreidle=%d spd=%d lnk=%d",
                 Dsts, (Dsts >> 22) & 1, (Dsts >> 23) & 1, Dsts & 7,
                 (Dsts >> 18) & 0xF);
  Say (Buf);

  //
  // GCC read-only.  GDSCR bit31 = power on; CBCR bit31 = CLK_OFF.
  // 0x0F084 / 0x0F000 printed as USB3_PHY_GDSCR / BCR candidates.
  //
  Gdscr    = Usb150Rd (Gcc + 0x0F004);
  CbM      = Usb150Rd (Gcc + 0x0F010);
  CbS      = Usb150Rd (Gcc + 0x0F014);
  CbU      = Usb150Rd (Gcc + 0x0F018);
  GdscrPhy = Usb150Rd (Gcc + 0x0F084);
  Bcr      = Usb150Rd (Gcc + 0x0F000);
  UnicodeSPrint (Buf, sizeof (Buf),
                 L"  [USB155] gcc usb gdscr=%08x power_on=%d cbcr=%08x/%08x/%08x clk_off=%d%d%d phy=%08x phy_on=%d bcr=%08x",
                 Gdscr, (Gdscr >> 31) & 1, CbM, CbS, CbU,
                 (CbM >> 31) & 1, (CbS >> 31) & 1, (CbU >> 31) & 1,
                 GdscrPhy, (GdscrPhy >> 31) & 1, Bcr);
  Say (Buf);
  UnicodeSPrint (Buf, sizeof (Buf),
                 L"  [USB155] gcc aux: cfg_noc=%08x aggre=%08x ahb2phy=%08x clkref=%08x",
                 Usb150Rd (Gcc + 0x0502C), Usb150Rd (Gcc + 0x8201C),
                 Usb150Rd (Gcc + 0x6A004), Usb150Rd (Gcc + 0x8C010));
  Say (Buf);
  Hs = Usb150Rd (Scratch + 0x10);
  Ss = Usb150Rd (Scratch + 0x30);
  UnicodeSPrint (Buf, sizeof (Buf),
                 L"  [USB155] qscratch readonly: HS=%08x SS=%08x", Hs, Ss);
  Say (Buf);

  for (N = 0; N < 8; N++) {
    O = 0x0F000 + (N * 0x20);
    UnicodeSPrint (Buf, sizeof (Buf),
                   L"  [USB155] gcc[%03x]=%08x %08x %08x %08x %08x %08x %08x %08x",
                   (UINT32)O,
                   Usb150Rd (Gcc + O + 0x00), Usb150Rd (Gcc + O + 0x04),
                   Usb150Rd (Gcc + O + 0x08), Usb150Rd (Gcc + O + 0x0C),
                   Usb150Rd (Gcc + O + 0x10), Usb150Rd (Gcc + O + 0x14),
                   Usb150Rd (Gcc + O + 0x18), Usb150Rd (Gcc + O + 0x1C));
    Say (Buf);
  }

  Say (L"  [USB155] read-only diagnostics done, returning to BDS");
}

'''
a = s.index("STATIC VOID\nUsb152Diag (")
b = s.index("EFI_STATUS\nEFIAPI\nVermeerMenuDxeEntry (")
s = s[:a] + NEW_DIAG + s[b:]

# ---- entry tail -----------------------------------------------------------
TAIL_A = '  Say (L"  [MENU152] minimal menu: read-only diag, no writes, returning to BDS");'
TAIL_B = '  Say (L"  [MENU152] diag done - no CpuDeadLoop, returning");'
if TAIL_A not in s or TAIL_B not in s:
    print("patch_usb155: FATAL entry tail anchors not found")
    sys.exit(1)
a = s.index(TAIL_A)
b = s.index(TAIL_B) + len(TAIL_B)
NEW_TAIL = '''  Say (L"  [MENU155] read-only GCC/clock diagnostics (no DCTL/PHYCFG/QSCRATCH writes)");
  {
    STATIC UINTN  mGuiDisabled155 = 0;

    if (mGuiDisabled155 == 0) {
      Usb155Diag ();
    } else {
      RunMenu ();
    }
  }
  Say (L"  [MENU155] done, returning to BDS");'''
s = s[:a] + NEW_TAIL + s[b:]

# ---- sanity: no writes left in the diag path ------------------------------
for bad in ("Usb150Wr (Dwc3", "Usb150Wr (Gcc", "Usb150Wr (Scratch",
            "CpuDeadLoop ()"):
    if bad in s:
        print("patch_usb155: FATAL still contains %r" % bad)
        sys.exit(1)

P.write_text(s, encoding="utf-8")
print("PATCH_USB155 OK: Usb155Diag (read-only GCC/DWC3 decode), no writes, MENU155 tail")
