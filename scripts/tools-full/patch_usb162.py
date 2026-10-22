#!/usr/bin/env python3
"""patch_usb162.py -- keys162: read-only DWC3 device event trace.

Baseline: pristine keys149 Menu (same source all keys15x patch scripts start
from).  Replaces the keys150 diag block with an event-trace-only block:

  * keep the PHY alive like keys161 (clear GUSB2PHYCFG SUSPHY/ENBLSLPM only,
    never touch DCTL.CSFTRST);
  * allocate a 4 KiB page-aligned event buffer, point GEVNTADRLO/HI at it,
    GEVNTSIZ = 0x1000, DEVTEN = 0x7, DCFG = high speed / address 0;
  * DCTL.RUN_STOP retried up to 3x if the core reports halted;
  * NO endpoint configuration, NO SETUP TRB, NO STARTTRANSFER, NO descriptors;
  * resident loop only drains GEVNTCOUNT and prints every raw 32-bit event;
    write-back is the number of consumed BYTES (Linux dwc3 does
    writel(GEVNTCOUNT(0), count) with count = consumed bytes), keeping the
    event ring in sync instead of writing 0 or an event count.

Idempotent via the "[MENU162]" marker.
"""
import pathlib
import sys

P = pathlib.Path("/root/k70/uefi/Platforms/Xiaomi/vermeerPkg/Drivers/VermeerMenuDxe/VermeerMenuDxe.c")
s = P.read_text(encoding="utf-8")

if "[MENU162]" in s:
    print("patch_usb162: already patched")
    sys.exit(0)

if "[MENU150]" not in s or "Usb150LateDiag" not in s:
    print("patch_usb162: FATAL pristine keys150 menu block not found")
    sys.exit(1)

NEW_FB = r'''STATIC
VOID
ForceLoadSimpleFb (
  VOID
  )
{
  //
  // keys162: SimpleFb LoadImage/StartImage intentionally disabled (text UI only).
  //
  if (mFbLoadTried) {
    return;
  }
  mFbLoadTried = TRUE;
  Say (L"  [UI162] SimpleFb load disabled (keys162)");
}

'''

NEW_BLOCK = r'''//
// ===================== keys162: read-only DWC3 event trace ==================
//
// Goal: prove device events arrive and get the GEVNTCOUNT write-back right
// (bytes consumed) WITHOUT arming EP0, without handing any transfer to the
// controller, without descriptors.  If this build survives a SETUP, the reset
// in keys161 came from our EP0/TRB handling, not from event delivery.
//
#define USB162_BASE            0x0A600000
#define USB162_GSNPSID         0x0C120
#define USB162_GCTL            0x0C110
#define USB162_GUSB2PHYCFG     0x0C200
#define USB162_GEVNTADRLO      0x0C400
#define USB162_GEVNTADRHI      0x0C404
#define USB162_GEVNTSIZ        0x0C408
#define USB162_GEVNTCOUNT      0x0C40C
#define USB162_DCFG            0x0C700
#define USB162_DCTL            0x0C704
#define USB162_DEVTEN          0x0C708
#define USB162_DSTS            0x0C70C

#define USB162_DCTL_RUN_STOP   (1U << 31)
#define USB162_DSTS_DEVCTRLHLT (1U << 22)
#define USB162_PHYCFG_CLEAR    ((1U << 8) | (1U << 6))
#define USB162_EVT_SIZE        0x1000
#define USB162_EVT_MASK        (USB162_EVT_SIZE - 1)

STATIC UINT8   *mUsb162Dma;
STATIC UINTN    mUsb162EvtPos;
STATIC UINT32   mUsb162RawLogs;
STATIC UINT32   mUsb162LastCount;
STATIC UINT32   mUsb162LastDsts;
STATIC UINT32   mUsb162Consumed;

STATIC UINT32
Usb162Rd (
  IN UINTN  Off
  )
{
  return *(volatile UINT32 *)(UINTN)(USB162_BASE + Off);
}

STATIC VOID
Usb162Wr (
  IN UINTN   Off,
  IN UINT32  Value
  )
{
  *(volatile UINT32 *)(UINTN)(USB162_BASE + Off) = Value;
  __asm__ __volatile__ ("dsb sy" ::: "memory");
}

STATIC VOID
Usb162Inval (
  IN UINTN  Address,
  IN UINTN  Length
  )
{
  UINTN  Line;

  for (Line = Address & ~((UINTN)0x3F); Line < Address + Length; Line += 0x40) {
    __asm__ __volatile__ ("dc civac, %0" :: "r" (Line) : "memory");
  }
  __asm__ __volatile__ ("dsb sy" ::: "memory");
}

STATIC VOID
Usb162Print (
  IN CONST CHAR16  *Format,
  ...
  )
{
  CHAR16   Buf[200];
  VA_LIST  Marker;

  VA_START (Marker, Format);
  UnicodeVSPrint (Buf, sizeof (Buf), Format, Marker);
  VA_END (Marker);
  Say (Buf);
}

STATIC VOID
Usb162Poll (
  VOID
  )
{
  UINT32  Count;
  UINT32  Chunk;
  UINT32  Ev;
  UINTN   Off;
  UINTN   I;

  Count = Usb162Rd (USB162_GEVNTCOUNT) & 0xFFFF;
  if (Count == 0) {
    return;
  }
  Chunk = Count & (UINT32)~3U;
  if (Chunk > USB162_EVT_SIZE) {
    Chunk = USB162_EVT_SIZE;
  }
  Usb162Inval ((UINTN)mUsb162Dma, USB162_EVT_SIZE);
  for (I = 0; I < Chunk; I += 4) {
    Off = mUsb162EvtPos & USB162_EVT_MASK;
    Ev  = *(volatile UINT32 *)(UINTN)(mUsb162Dma + Off);
    mUsb162EvtPos = (mUsb162EvtPos + 4) & USB162_EVT_MASK;
    if (mUsb162RawLogs < 8) {
      mUsb162RawLogs++;
      Usb162Print (L"  [USB162] evt raw=%08x off=%x", Ev, (UINT32)Off);
    }
  }
  //
  // Linux dwc3_gadget_process_event(): writel(DWC3_GEVNTCOUNT(0), count)
  // where count is the number of BYTES consumed by this call.
  //
  Usb162Wr (USB162_GEVNTCOUNT, Chunk);
  mUsb162Consumed += Chunk;
}

STATIC VOID
Usb162Stat (
  VOID
  )
{
  UINT32  Dsts;
  UINT32  Count;

  Dsts  = Usb162Rd (USB162_DSTS);
  Count = Usb162Rd (USB162_GEVNTCOUNT) & 0xFFFF;
  Usb162Print (L"  [USB162] poll: cnt=%08x DSTS=%08x DCTL=%08x consumed=%u",
               Count, Dsts, Usb162Rd (USB162_DCTL), mUsb162Consumed);
  if ((Dsts != mUsb162LastDsts) || (Count != mUsb162LastCount)) {
    mUsb162LastDsts  = Dsts;
    mUsb162LastCount = Count;
    Usb162Print (L"  [USB162] regs: GCTL=%08x PHYCFG=%08x DEVTEN=%08x SIZ=%08x",
                 Usb162Rd (USB162_GCTL), Usb162Rd (USB162_GUSB2PHYCFG),
                 Usb162Rd (USB162_DEVTEN), Usb162Rd (USB162_GEVNTSIZ));
    Usb162Print (L"  [USB162] regs2: DCFG=%08x evt=%08x%08x pos=%x",
                 Usb162Rd (USB162_DCFG), Usb162Rd (USB162_GEVNTADRHI),
                 Usb162Rd (USB162_GEVNTADRLO), (UINT32)mUsb162EvtPos);
  }
}

STATIC VOID
Usb162Init (
  VOID
  )
{
  EFI_PHYSICAL_ADDRESS  DmaPa;
  EFI_STATUS            Status;
  UINTN                 I;
  UINTN                 Ticks;
  UINT32                Dsts;

  Status = gBS->AllocatePages (AllocateAnyPages, EfiBootServicesData, 4, &DmaPa);
  if (EFI_ERROR (Status)) {
    Say (L"  [USB162] FATAL: no DMA pages");
    return;
  }
  mUsb162Dma = (UINT8 *)(UINTN)DmaPa;
  ZeroMem (mUsb162Dma, USB162_EVT_SIZE);
  Usb162Print (L"  [USB162] dma=%08x%08x (4 KiB event buffer)",
               (UINT32)(((UINT64)(UINTN)mUsb162Dma) >> 32), (UINT32)(UINTN)mUsb162Dma);

  //
  // 1) Keep the PHY alive exactly like keys161: never touch DCTL.CSFTRST,
  //    only clear PHY suspend / suspend-on-sleep.
  //
  Usb162Wr (USB162_GUSB2PHYCFG, Usb162Rd (USB162_GUSB2PHYCFG) & ~USB162_PHYCFG_CLEAR);
  gBS->Stall (20000);

  //
  // 2) Event buffer (polled; GEVNTSIZ bit31 = 0 like the vendor's unmasked path).
  //
  Usb162Wr (USB162_GEVNTADRLO, (UINT32)(UINTN)mUsb162Dma);
  Usb162Wr (USB162_GEVNTADRHI, (UINT32)(((UINT64)(UINTN)mUsb162Dma) >> 32));
  Usb162Wr (USB162_GEVNTSIZ, USB162_EVT_SIZE);
  Usb162Wr (USB162_GEVNTCOUNT, Usb162Rd (USB162_GEVNTCOUNT) & 0xFFFF);
  mUsb162EvtPos = 0;
  Usb162Print (L"  [USB162] evt: addr=%08x%08x siz=%08x cnt=%08x",
               Usb162Rd (USB162_GEVNTADRHI), Usb162Rd (USB162_GEVNTADRLO),
               Usb162Rd (USB162_GEVNTSIZ), Usb162Rd (USB162_GEVNTCOUNT));

  //
  // 3) High speed / address 0; only the three device events we care about.
  //    No endpoint configuration, no TRBs: EP0 is left completely alone.
  //
  Usb162Wr (USB162_DCFG, Usb162Rd (USB162_DCFG) & ~(7U | (0x7FU << 3)));
  Usb162Wr (USB162_DEVTEN, 0x7);

  //
  // 4) RUN_STOP only (no CSFTRST), retry up to 3x if the core reports halted.
  //
  for (I = 0; I < 3; I++) {
    if ((Usb162Rd (USB162_DSTS) & USB162_DSTS_DEVCTRLHLT) == 0) {
      break;
    }
    Usb162Wr (USB162_DCTL, Usb162Rd (USB162_DCTL) & ~USB162_DCTL_RUN_STOP);
    gBS->Stall (1000);
    Usb162Wr (USB162_DCTL, Usb162Rd (USB162_DCTL) | USB162_DCTL_RUN_STOP);
    for (Ticks = 0; Ticks < 200; Ticks++) {
      if ((Usb162Rd (USB162_DSTS) & USB162_DSTS_DEVCTRLHLT) == 0) {
        break;
      }
      gBS->Stall (1000);
    }
  }

  Dsts = Usb162Rd (USB162_DSTS);
  Usb162Print (L"  [USB162] bringup done: hlt22=%d phycfg_bit6=%d spd=%u GSNPSID=%08x",
               (Dsts >> 22) & 1, (Usb162Rd (USB162_GUSB2PHYCFG) >> 6) & 1, Dsts & 7,
               Usb162Rd (USB162_GSNPSID));
}

'''

c = s.find("STATIC\nVOID\nForceLoadSimpleFb (\n")
if c < 0:
    print("patch_usb162: FATAL ForceLoadSimpleFb not found")
    sys.exit(1)
d = s.find("STATIC\nVOID\nProbeGop (\n", c)
if d < 0:
    print("patch_usb162: FATAL ProbeGop not found")
    sys.exit(1)
s = s[:c] + NEW_FB + s[d:]

a = s.find("STATIC UINT32\nUsb150Rd (\n")
if a < 0:
    print("patch_usb162: FATAL Usb150Rd block not found")
    sys.exit(1)
b = s.find("EFI_STATUS\nEFIAPI\nVermeerMenuDxeEntry", a)
if b < 0:
    print("patch_usb162: FATAL entry not found")
    sys.exit(1)
s = s[:a] + NEW_BLOCK + s[b:]

a = s.find('  Say (L"  [MENU150] console stays on, USB150 diag then photo halt");')
if a < 0:
    print("patch_usb162: FATAL MENU150 entry tail not found")
    sys.exit(1)
b = s.find("  CpuDeadLoop ();", a)
if b < 0:
    print("patch_usb162: FATAL CpuDeadLoop not found")
    sys.exit(1)
b += len("  CpuDeadLoop ();")

NEW_TAIL = '''  Say (L"  [MENU162] event-trace only: no EP0 arm, no transfers");
  {
    STATIC UINTN  mGuiDisabled162 = 0;
    STATIC UINTN  mTicks162       = 0;
    EFI_INPUT_KEY Key;
    BOOLEAN       Got;

    Usb162Init ();
    for (;;) {
      Usb162Poll ();
      if ((mTicks162 % 1000) == 0) {
        Usb162Stat ();
      }
      if ((mTicks162 % 5000) == 0) {
        Say (L"  [USB162] alive");
      }
      mTicks162++;
      Got = FALSE;
      if (mIn != NULL) {
        if (mIn->ReadKeyStroke (mIn, &Key) == EFI_SUCCESS) {
          Got = TRUE;
        }
      }
      if (Got) {
        break;
      }
      gBS->Stall (1000);
    }
    Say (L"  [MENU162] key pressed, leaving resident loop");
    if (mGuiDisabled162 == 0) {
      RunMenu ();
    }
  }
  Say (L"  [MENU162] done, returning to BDS");'''

s = s[:a] + NEW_TAIL + s[b:]

# ---- sanity -----------------------------------------------------------------
for bad in ("Usb150Wr (", "Usb150Rd (", "Usb150Dump (", "Usb150LateDiag", "CpuDeadLoop ()",
            "0x0010F004", "0x0010F000", "0x0A6F8800", "USB162_DCTL_CSFTRST",
            "DEPCMD", "STARTTRANSFER"):
    if bad in s:
        print("patch_usb162: FATAL still contains %r" % bad)
        sys.exit(1)
for need in ("[MENU162]", "[USB162]", "Usb162Init", "Usb162Poll", "Usb162Stat", "RunMenu ()",
             "USB162_GEVNTCOUNT", "consumed"):
    if need not in s:
        print("patch_usb162: FATAL missing %r" % need)
        sys.exit(1)

P.write_text(s, encoding="utf-8")
print("patch_usb162: Menu -> DWC3 device event-trace only (no EP0 arm/transfers)")
print("PATCH_USB162 OK")
