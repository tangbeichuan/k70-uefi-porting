#!/usr/bin/env python3
"""patch_usb163.py -- keys163: clear screen, only USB event trace, then halt.

Baseline: pristine keys149 Menu (as all keys15x/16x menu patches).
Baseline feature set: keys162 (PHY kept alive, NO DCTL.CSFTRST, NO EP0 at all).

This build is meant to be read from a single photo:
  1. clear the whole screen (GOP EfiBltVideoFill black, fallback ConOut ClearScreen);
  2. (re)install the DWC3 event ring exactly like keys162:
     event-buffer address -> GEVNTSIZ=0x1000 (bit31=0) -> GEVNTCOUNT=0 ->
     DCFG=HS/addr0 -> DEVTEN=0x7 -> DCTL.RUN_STOP keepalive (hlt22);
  3. print AT MOST 8 short event lines at the top of the screen plus one poll
     line per second and one final done line;
  4. halt with CpuDeadLoop() after 8 s or as soon as 8 events arrived, so the
     screen is frozen with only our lines.

No EP0 configuration / no TRB / no descriptors / no CSFTRST.
Idempotent via the "[MENU163]" marker.
"""
import pathlib
import sys

P = pathlib.Path("/root/k70/uefi/Platforms/Xiaomi/vermeerPkg/Drivers/VermeerMenuDxe/VermeerMenuDxe.c")
s = P.read_text(encoding="utf-8")

if "[MENU163]" in s:
    print("patch_usb163: already patched")
    sys.exit(0)

if "[MENU150]" not in s or "Usb150LateDiag" not in s:
    print("patch_usb163: FATAL pristine keys150 menu block not found")
    sys.exit(1)

NEW_FB = r'''STATIC
VOID
ForceLoadSimpleFb (
  VOID
  )
{
  //
  // keys163: SimpleFb LoadImage/StartImage intentionally disabled (text UI only).
  //
  if (mFbLoadTried) {
    return;
  }
  mFbLoadTried = TRUE;
  Say (L"  [UI163] SimpleFb load disabled (keys163)");
}

'''

NEW_BLOCK = r'''//
// ============ keys163: clear screen + DWC3 event trace + halt ===============
//
// Read-from-one-photo diagnostic.  We keep the controller in device mode with
// the PHY awake (keys161 lesson: never touch DCTL.CSFTRST) and only install the
// event ring; EP0 is left completely alone.  Events are printed at the top of a
// freshly cleared screen and the CPU is halted so the text stays visible.
//
#define USB163_BASE            0x0A600000
#define USB163_GSNPSID         0x0C120
#define USB163_GCTL            0x0C110
#define USB163_GUSB2PHYCFG     0x0C200
#define USB163_GEVNTADRLO      0x0C400
#define USB163_GEVNTADRHI      0x0C404
#define USB163_GEVNTSIZ        0x0C408
#define USB163_GEVNTCOUNT      0x0C40C
#define USB163_DCFG            0x0C700
#define USB163_DCTL            0x0C704
#define USB163_DEVTEN          0x0C708
#define USB163_DSTS            0x0C70C

#define USB163_DCTL_RUN_STOP   (1U << 31)
#define USB163_DSTS_DEVCTRLHLT (1U << 22)
#define USB163_PHYCFG_CLEAR    ((1U << 8) | (1U << 6))
#define USB163_EVT_SIZE        0x1000
#define USB163_EVT_MASK        (USB163_EVT_SIZE - 1)

STATIC UINT8   *mUsb163Dma;
STATIC UINTN    mUsb163EvtPos;
STATIC UINTN    mUsb163Row;
STATIC UINT32   mUsb163Evts;
STATIC UINT32   mUsb163Consumed;

STATIC UINT32
Usb163Rd (
  IN UINTN  Off
  )
{
  return *(volatile UINT32 *)(UINTN)(USB163_BASE + Off);
}

STATIC VOID
Usb163Wr (
  IN UINTN   Off,
  IN UINT32  Value
  )
{
  *(volatile UINT32 *)(UINTN)(USB163_BASE + Off) = Value;
  __asm__ __volatile__ ("dsb sy" ::: "memory");
}

STATIC VOID
Usb163Inval (
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

//
// Print one short line at the top of the screen (row counter) and mirror it to
// the serial DEBUG channel so a photo is not the only record.
//
STATIC VOID
Usb163Line (
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
  DEBUG ((DEBUG_ERROR, "%a\n", Ascii));

  if (mOut != NULL) {
    mOut->SetCursorPosition (mOut, 0, mUsb163Row);
    mOut->OutputString (mOut, Buf);
  }
  mUsb163Row++;
}

STATIC VOID
Usb163Clear (
  VOID
  )
{
  EFI_GRAPHICS_OUTPUT_PROTOCOL  *Gop = NULL;
  UINT32                        W;
  UINT32                        H;

  if (!EFI_ERROR (gBS->LocateProtocol (&gEfiGraphicsOutputProtocolGuid, NULL, (VOID **)&Gop)) &&
      (Gop != NULL) && (Gop->Mode != NULL) && (Gop->Mode->Info != NULL)) {
    W = (UINT32)Gop->Mode->Info->HorizontalResolution;
    H = (UINT32)Gop->Mode->Info->VerticalResolution;
    FillRect (Gop, 0, 0, W, H, 0x000000);
  } else if ((mOut != NULL) && (mOut->ClearScreen != NULL)) {
    mOut->ClearScreen (mOut);
  }

  if (mOut != NULL) {
    if (mOut->SetAttribute != NULL) {
      mOut->SetAttribute (mOut, EFI_TEXT_ATTR (EFI_LIGHTGRAY, EFI_BLACK));
    }
    mOut->SetCursorPosition (mOut, 0, 0);
  }
  mUsb163Row = 0;
}

STATIC VOID
Usb163Poll (
  VOID
  )
{
  UINT32  Count;
  UINT32  Chunk;
  UINT32  Ev;
  UINTN   Off;
  UINTN   I;

  Count = Usb163Rd (USB163_GEVNTCOUNT) & 0xFFFF;
  if (Count == 0) {
    return;
  }
  Chunk = Count & (UINT32)~3U;
  if (Chunk > USB163_EVT_SIZE) {
    Chunk = USB163_EVT_SIZE;
  }
  Usb163Inval ((UINTN)mUsb163Dma, USB163_EVT_SIZE);
  for (I = 0; I < Chunk; I += 4) {
    Off = mUsb163EvtPos & USB163_EVT_MASK;
    Ev  = *(volatile UINT32 *)(UINTN)(mUsb163Dma + Off);
    mUsb163EvtPos = (mUsb163EvtPos + 4) & USB163_EVT_MASK;
    if (mUsb163Evts < 8) {
      Usb163Line (L"[163] evt %u raw=%08x", mUsb163Evts, Ev);
    }
    mUsb163Evts++;
  }
  //
  // Consumed BYTES back into GEVNTCOUNT (Linux dwc3: writel(GEVNTCOUNT, count)).
  //
  Usb163Wr (USB163_GEVNTCOUNT, Chunk);
  mUsb163Consumed += Chunk;
}

STATIC VOID
Usb163PollLine (
  VOID
  )
{
  Usb163Line (L"[163] poll cnt=%04x DSTS=%08x DCTL=%08x consumed=%u",
              Usb163Rd (USB163_GEVNTCOUNT) & 0xFFFF,
              Usb163Rd (USB163_DSTS),
              Usb163Rd (USB163_DCTL),
              mUsb163Consumed);
}

STATIC VOID
Usb163Init (
  VOID
  )
{
  EFI_PHYSICAL_ADDRESS  DmaPa;
  EFI_STATUS            Status;
  UINTN                 I;
  UINTN                 Ticks;

  Status = gBS->AllocatePages (AllocateAnyPages, EfiBootServicesData, 4, &DmaPa);
  if (EFI_ERROR (Status)) {
    Usb163Line (L"[163] FATAL no dma pages");
    return;
  }
  mUsb163Dma = (UINT8 *)(UINTN)DmaPa;
  ZeroMem (mUsb163Dma, USB163_EVT_SIZE);

  //
  // 1) PHY alive (keys161/162 rule: clear SUSPHY/ENBLSLPM, never CSFTRST).
  //
  Usb163Wr (USB163_GUSB2PHYCFG, Usb163Rd (USB163_GUSB2PHYCFG) & ~USB163_PHYCFG_CLEAR);
  gBS->Stall (20000);

  //
  // 2) Event ring: address -> size (bit31=0) -> count, same order as the vendor
  //    UsbfnDwc3Dxe (GEVNTADRLO/HI, GEVNTSIZ, GEVNTCOUNT) and only then DEVTEN.
  //
  Usb163Wr (USB163_GEVNTADRLO, (UINT32)(UINTN)mUsb163Dma);
  Usb163Wr (USB163_GEVNTADRHI, (UINT32)(((UINT64)(UINTN)mUsb163Dma) >> 32));
  Usb163Wr (USB163_GEVNTSIZ, USB163_EVT_SIZE);
  Usb163Wr (USB163_GEVNTCOUNT, Usb163Rd (USB163_GEVNTCOUNT) & 0xFFFF);
  mUsb163EvtPos = 0;
  mUsb163Evts   = 0;
  mUsb163Consumed = 0;

  //
  // 3) High speed / address 0, then the three device events (disconnect, reset,
  //    connect-done).  Endpoint events are not gated by DEVTEN.
  //
  Usb163Wr (USB163_DCFG, Usb163Rd (USB163_DCFG) & ~(7U | (0x7FU << 3)));
  Usb163Wr (USB163_DEVTEN, 0x7);

  //
  // 4) RUN_STOP keepalive only (bit30 untouched); retry 3x if halted.
  //
  for (I = 0; I < 3; I++) {
    if ((Usb163Rd (USB163_DSTS) & USB163_DSTS_DEVCTRLHLT) == 0) {
      break;
    }
    Usb163Wr (USB163_DCTL, Usb163Rd (USB163_DCTL) & ~USB163_DCTL_RUN_STOP);
    gBS->Stall (1000);
    Usb163Wr (USB163_DCTL, Usb163Rd (USB163_DCTL) | USB163_DCTL_RUN_STOP);
    for (Ticks = 0; Ticks < 200; Ticks++) {
      if ((Usb163Rd (USB163_DSTS) & USB163_DSTS_DEVCTRLHLT) == 0) {
        break;
      }
      gBS->Stall (1000);
    }
  }

  Usb163Line (L"[163] init id=%08x siz=%08x devten=%08x phycfg=%08x",
              Usb163Rd (USB163_GSNPSID), Usb163Rd (USB163_GEVNTSIZ),
              Usb163Rd (USB163_DEVTEN), Usb163Rd (USB163_GUSB2PHYCFG));
}

'''

c = s.find("STATIC\nVOID\nForceLoadSimpleFb (\n")
if c < 0:
    print("patch_usb163: FATAL ForceLoadSimpleFb not found")
    sys.exit(1)
d = s.find("STATIC\nVOID\nProbeGop (\n", c)
if d < 0:
    print("patch_usb163: FATAL ProbeGop not found")
    sys.exit(1)
s = s[:c] + NEW_FB + s[d:]

a = s.find("STATIC UINT32\nUsb150Rd (\n")
if a < 0:
    print("patch_usb163: FATAL Usb150Rd block not found")
    sys.exit(1)
b = s.find("EFI_STATUS\nEFIAPI\nVermeerMenuDxeEntry", a)
if b < 0:
    print("patch_usb163: FATAL entry not found")
    sys.exit(1)
s = s[:a] + NEW_BLOCK + s[b:]

a = s.find('  Say (L"  [MENU150] console stays on, USB150 diag then photo halt");')
if a < 0:
    print("patch_usb163: FATAL MENU150 entry tail not found")
    sys.exit(1)
b = s.find("  CpuDeadLoop ();", a)
if b < 0:
    print("patch_usb163: FATAL CpuDeadLoop not found")
    sys.exit(1)
b += len("  CpuDeadLoop ();")

NEW_TAIL = '''  Say (L"  [MENU163] clear screen + USB event trace + halt");
  {
    UINTN  Ticks = 0;

    Usb163Clear ();
    Usb163Init ();
    while (Ticks < 8000) {
      Usb163Poll ();
      if ((Ticks % 1000) == 0) {
        Usb163PollLine ();
      }
      if (mUsb163Evts >= 8) {
        break;
      }
      gBS->Stall (1000);
      Ticks++;
    }
    Usb163Poll ();
    Usb163Line (L"[163] done evts=%u bytes=%u", mUsb163Evts, mUsb163Consumed);
    if (mUsb163Evts == 0xFFFFFFFFU) {
      RunMenu ();       // never taken: keeps RunMenu referenced (-Wunused-function)
    }
    CpuDeadLoop ();
  }'''

s = s[:a] + NEW_TAIL + s[b:]

# ---- sanity -----------------------------------------------------------------
for bad in ("Usb150Wr (", "Usb150Rd (", "Usb150Dump (", "Usb150LateDiag",
            "0x0010F004", "0x0010F000", "0x0A6F8800", "USB163_DCTL_CSFTRST",
            "DEPCMD", "STARTTRANSFER"):
    if bad in s:
        print("patch_usb163: FATAL still contains %r" % bad)
        sys.exit(1)
for need in ("[MENU163]", "[163] evt", "[163] poll", "[163] done", "[163] init",
             "Usb163Init", "Usb163Poll", "Usb163PollLine", "Usb163Clear",
             "CpuDeadLoop ()", "EfiBltVideoFill", "ClearScreen",
             "USB163_GEVNTCOUNT", "consumed"):
    if need not in s:
        print("patch_usb163: FATAL missing %r" % need)
        sys.exit(1)

P.write_text(s, encoding="utf-8")
print("patch_usb163: Menu -> clear screen + USB event trace only, then halt")
print("PATCH_USB163 OK")
