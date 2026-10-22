#!/usr/bin/env python3
"""mk166.py -- generate patch_usb166.py from patch_usb165.py.

keys166 = keys165 (EP0 + replug + raw event trace + 20 s halt) plus:
  * Apps SMMU bypass for the USB0 SID 0x40 (fallback 0x60) -- SMMU-500 at
    0x15000000, already mapped by MemoryMapLib "SMMU" region.
  * vendor event-ring write order (ADDRHI -> ADDRLO -> SIZ -> COUNT) and
    vendor SIZ value (bit31 = interrupt masked) + DEVTEN = 0x1277.
  * DMA allocation forced below 4 GiB (AllocateMaxAddress 0xFFFFF000).
  * bringup line prints evtaddr (HI/LO).
"""
import pathlib
import sys

TOOLS = pathlib.Path("/mnt/d/本地项目-01/_tools")
src = (TOOLS / "patch_usb165.py").read_text(encoding="utf-8")

# ---- 1) 165 -> 166 (token-wise to be safe) -----------------------------------
for old, new in (
    ("USB165", "USB166"),
    ("Usb165", "Usb166"),
    ("mUsb165", "mUsb166"),
    ("mTicks165", "mTicks166"),
    ("mShown165", "mShown166"),
    ("mGuiDisabled165", "mGuiDisabled166"),
    ("[165]", "[166]"),
    ("MENU165", "MENU166"),
    ("UI165", "UI166"),
    ("keys165", "keys166"),
    ("PATCH_USB165", "PATCH_USB166"),
    ("mk165.py", "mk166.py"),
    ("patch_usb165.py", "patch_usb166.py"),
):
    src = src.replace(old, new)

# ---- 2) DMA below 4 GiB -----------------------------------------------------
OLD_ALLOC = "  Status = gBS->AllocatePages (AllocateAnyPages, EfiBootServicesData, USB166_DMA_SIZE / 0x1000, &DmaPa);"
NEW_ALLOC = (
    "  //\n"
    "  // keys166: force the event ring / TRB DMA below 4 GiB (32-bit DMA safe).\n"
    "  //\n"
    "  DmaPa  = 0xFFFFF000ULL;\n"
    "  Status = gBS->AllocatePages (AllocateMaxAddress, EfiBootServicesData, USB166_DMA_SIZE / 0x1000, &DmaPa);"
)
if OLD_ALLOC not in src:
    print("mk166: FATAL alloc line not found")
    sys.exit(1)
src = src.replace(OLD_ALLOC, NEW_ALLOC)

# ---- 3) vendor event-ring order / SIZ bit31 ---------------------------------
OLD_RING = """  Usb166Wr (USB166_GEVNTADRLO, (UINT32)(UINTN)mUsb166Dma);
  Usb166Wr (USB166_GEVNTADRHI, (UINT32)(((UINT64)(UINTN)mUsb166Dma) >> 32));
  Usb166Wr (USB166_GEVNTSIZ,   USB166_EVT_SIZE);
  Usb166Wr (USB166_GEVNTCOUNT, Usb166Rd (USB166_GEVNTCOUNT) & 0xFFFF);"""
NEW_RING = """  //
  // keys166: vendor write order (ADDRHI -> ADDRLO -> SIZ -> COUNT) and the vendor
  // value for GEVNTSIZ: bit31 = interrupt masked (0x80000000 | size), polled only.
  //
  Usb166Wr (USB166_GEVNTADRHI, (UINT32)(((UINT64)(UINTN)mUsb166Dma) >> 32));
  Usb166Wr (USB166_GEVNTADRLO, (UINT32)(UINTN)mUsb166Dma);
  Usb166Wr (USB166_GEVNTSIZ,   ((UINT32)1 << 31) | USB166_EVT_SIZE);
  Usb166Wr (USB166_GEVNTCOUNT, 0);"""
if OLD_RING not in src:
    print("mk166: FATAL event ring block not found")
    sys.exit(1)
src = src.replace(OLD_RING, NEW_RING)

# ---- 4) vendor DEVTEN -------------------------------------------------------
OLD_DEVTEN = "  Usb166Wr (USB166_DEVTEN, 0x7);"
NEW_DEVTEN = "  Usb166Wr (USB166_DEVTEN, 0x1277);   // vendor value: device events incl. connect/reset"
if OLD_DEVTEN not in src:
    print("mk166: FATAL DEVTEN line not found")
    sys.exit(1)
src = src.replace(OLD_DEVTEN, NEW_DEVTEN)

# ---- 5) SMMU bypass block, inserted before Usb166Init -----------------------
SMMU_BLOCK = r'''//
// keys166: Apps SMMU (SMMU-500) bypass for the DWC3 (USB0) stream.
// Base 0x15000000 is covered by the MemoryMapLib "SMMU" region, so no PEI change
// is needed.  xbl_ufs.dtb /soc/iort NAMEDNODE_USB0 SIDMAPPING: OutputBase = 0x40
// (OutputReference = APPS_MMU500_SMMU_APP).  SID 0x60 is only a fallback guess.
//
#define USB166_SMMU_BASE        0x15000000
#define USB166_SMMU_GR0_ID0     0x020
#define USB166_SMMU_GR0_ID1     0x024
#define USB166_SMMU_GR0_SMR(n)  (0x800 + ((n) * 4))
#define USB166_SMMU_GR0_S2CR(n) (0xC00 + ((n) * 4))
#define USB166_SMMU_SMR_VALID   0x80000000U
#define USB166_S2CR_TYPE_BYPASS (1U << 16)   // ARM SMMU-500 S2CR.TYPE: 0=trans, 1=bypass, 2=fault

STATIC UINT32
Usb166SmmuRd (
  IN UINTN Offset
  )
{
  return *(volatile UINT32 *)(UINTN)(USB166_SMMU_BASE + Offset);
}

STATIC VOID
Usb166SmmuWr (
  IN UINTN  Offset,
  IN UINT32 Value
  )
{
  *(volatile UINT32 *)(UINTN)(USB166_SMMU_BASE + Offset) = Value;
  gBS->Stall (10);
}

STATIC VOID
Usb166SmmuBypass (
  VOID
  )
{
  CONST UINT32  Cands[2] = { 0x40, 0x60 };   // 0x40 = USB0 (iort), 0x60 = fallback
  UINT32        Id0;
  UINT32        Id1;
  UINT32        NumSmrg;
  UINT32        Smr;
  UINT32        S2cr;
  UINT32        New;
  UINT32        Want;
  UINTN         I;
  UINTN         J;
  UINTN         Shown;
  UINTN         Valid;

  Id0     = Usb166SmmuRd (USB166_SMMU_GR0_ID0);
  Id1     = Usb166SmmuRd (USB166_SMMU_GR0_ID1);
  NumSmrg = Id0 & 0xFF;
  Usb166Print (L"  [166] smmu id0=%08x id1=%08x smrg=%u cb=%u", Id0, Id1, NumSmrg, Id1 & 0xFF);

  Shown = 0;
  Valid = 0;
  for (I = 0; I < NumSmrg; I++) {
    Smr = Usb166SmmuRd (USB166_SMMU_GR0_SMR (I));
    if ((Smr & USB166_SMMU_SMR_VALID) == 0) {
      continue;
    }
    Valid++;
    if (Shown < 10) {
      Usb166Print (L"  [166] smmu n=%u sid=%04x mask=%04x s2cr=%08x", I, Smr & 0xFFFF,
                   (Smr >> 16) & 0xFFFF, Usb166SmmuRd (USB166_SMMU_GR0_S2CR (I)));
      Shown++;
    }
  }
  Usb166Print (L"  [166] smmu valid=%u of %u", Valid, NumSmrg);

  for (J = 0; J < ARRAY_SIZE (Cands); J++) {
    Want = Cands[J];
    S2cr = 0;
    for (I = 0; I < NumSmrg; I++) {
      Smr = Usb166SmmuRd (USB166_SMMU_GR0_SMR (I));
      if (((Smr & USB166_SMMU_SMR_VALID) != 0) && ((Smr & 0xFFFF) == Want)) {
        S2cr = Usb166SmmuRd (USB166_SMMU_GR0_S2CR (I));
        break;
      }
    }
    if (I < NumSmrg) {
      New = USB166_S2CR_TYPE_BYPASS | (S2cr & 0xFF);
      Usb166SmmuWr (USB166_SMMU_GR0_S2CR (I), New);
      Usb166Print (L"  [166] smmu bypass sid=%04x n=%u s2cr %08x -> %08x", Want, I, S2cr,
                   Usb166SmmuRd (USB166_SMMU_GR0_S2CR (I)));
      continue;
    }
    for (I = 0; I < NumSmrg; I++) {
      if ((Usb166SmmuRd (USB166_SMMU_GR0_SMR (I)) & USB166_SMMU_SMR_VALID) == 0) {
        break;
      }
    }
    if (I < NumSmrg) {
      Usb166SmmuWr (USB166_SMMU_GR0_S2CR (I), USB166_S2CR_TYPE_BYPASS);
      Usb166SmmuWr (USB166_SMMU_GR0_SMR (I), USB166_SMMU_SMR_VALID | (Want & 0xFFFF));
      Usb166Print (L"  [166] smmu created sid=%04x n=%u smr=%08x s2cr=%08x", Want, I,
                   Usb166SmmuRd (USB166_SMMU_GR0_SMR (I)),
                   Usb166SmmuRd (USB166_SMMU_GR0_S2CR (I)));
    } else {
      Usb166Print (L"  [166] smmu no free slot for sid=%04x", Want);
    }
  }
}

'''

ANCHOR_INIT = "STATIC VOID\nUsb166Init (\n"
if ANCHOR_INIT not in src:
    print("mk166: FATAL Usb166Init anchor not found")
    sys.exit(1)
src = src.replace(ANCHOR_INIT, SMMU_BLOCK + ANCHOR_INIT, 1)

# ---- 6) call SMMU bypass after the PHY stage --------------------------------
OLD_CALL = """  Usb166Print (L"  [166] phycfg=%08x gctl=%08x dctl=%08x", Usb166Rd (USB166_GUSB2PHYCFG),
               Usb166Rd (USB166_GCTL), Usb166Rd (USB166_DCTL));"""
NEW_CALL = OLD_CALL + """

  //
  // 1c) keys166: bypass the Apps SMMU for the DWC3 stream(s) before touching the
  //     event ring, so event-DMA writes can no longer be silently dropped.
  //
  Usb166SmmuBypass ();"""
if OLD_CALL not in src:
    print("mk166: FATAL phy print anchor not found")
    sys.exit(1)
src = src.replace(OLD_CALL, NEW_CALL)

# ---- 7) bringup line prints evtaddr ----------------------------------------
OLD_BRINGUP = """  Usb166Print (L"  [166] bringup done: hlt22=%d phycfg_bit6=%d devspd=%u",
               (Dsts >> 22) & 1, (Usb166Rd (USB166_GUSB2PHYCFG) >> 6) & 1, Dsts & 7);"""
NEW_BRINGUP = """  Usb166Print (L"  [166] bringup done: hlt22=%d phycfg_bit6=%d devspd=%u evtaddr=%08x%08x",
               (Dsts >> 22) & 1, (Usb166Rd (USB166_GUSB2PHYCFG) >> 6) & 1, Dsts & 7,
               Usb166Rd (USB166_GEVNTADRHI), Usb166Rd (USB166_GEVNTADRLO));"""
if OLD_BRINGUP not in src:
    print("mk166: FATAL bringup print not found")
    sys.exit(1)
src = src.replace(OLD_BRINGUP, NEW_BRINGUP)

# ---- 8) sanity list additions ----------------------------------------------
OLD_NEED = '''for need in ("[MENU166]", "Usb166Init", "Usb166Poll", "Usb166Stat", "Usb166Clear",'''
NEW_NEED = '''for need in ("[MENU166]", "Usb166Init", "Usb166Poll", "Usb166Stat", "Usb166Clear",
             "Usb166SmmuBypass", "smmu bypass", "smmu created", "AllocateMaxAddress",
             "0x1277", "GEVNTADRHI", "evtaddr=",'''
if OLD_NEED not in src:
    print("mk166: FATAL sanity anchor not found")
    sys.exit(1)
src = src.replace(OLD_NEED, NEW_NEED)

for bad in ("AllocateAnyPages",):
    if bad in src:
        print("mk166: FATAL generated file still contains %r" % bad)
        sys.exit(1)

out = TOOLS / "patch_usb166.py"
out.write_text(src, encoding="utf-8")
print("mk166: wrote %s (%d bytes)" % (out, len(src)))
