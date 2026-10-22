#!/usr/bin/env python3
"""patch_usb160.py -- keys160: Menu hosts a MINIMAL DWC3 device-mode EP0 gadget.

Baseline: pristine keys149 Menu (same source patch_usb157.py starts from), so
this replaces the keys150 diag block and the entry tail exactly like
patch_usb157.py does, but instead of a read-only monitor it installs:

  * a 16 KiB page-aligned DMA area (AllocatePages);
  * DWC3 device soft reset (DCTL.CSFTRST, poll self-clear);
  * event buffer at 0xC400/0x404/0x408 = 4 KiB, GEVNTSIZ bit31 = interrupt
    masked, polled from the resident loop; GEVNTCOUNT written back to clear;
  * DCFG = high speed / address 0, DEVTEN = 0x7 (disconnect / USB reset /
    connect done);
  * EP0 OUT (dep 0) and EP0 IN (dep 1): DEPSTARTCFG + SETEPCONFIG(512) +
    SETTRANSFRESOURCE; DALEPENA = 0x3; arm a SETUP TRB; DCTL.RUN_STOP;
  * polling loop handles: device events (reset / connect done), XferComplete
    (SETUP -> parse request, DATA -> wait status, STATUS -> re-arm SETUP),
    XferNotReady (control status phase -> start status TRB);
  * descriptors: device (VID 0x1209 / PID 0xC101), configuration (1 interface,
    0 endpoints), strings (en-US, "Vermeer", "K70 UEFI DEBUG").
  * no QSCRATCH writes, no GCC access, no CpuDeadLoop, never returns to BDS.

The DEPCMD / TRB / event bit layout is copied verbatim from the hardware
validated reference (ios-vermeer-lab xnu patch 0073-sweet-usb-device-ep0.patch),
which drives the same Synopsys DWC3 core in device mode.

Idempotent via the "[MENU160]" marker.
"""
import pathlib
import sys

P = pathlib.Path("/root/k70/uefi/Platforms/Xiaomi/vermeerPkg/Drivers/VermeerMenuDxe/VermeerMenuDxe.c")
s = P.read_text(encoding="utf-8")

if "[MENU160]" in s:
    print("patch_usb160: already patched")
    sys.exit(0)

if "[MENU150]" not in s or "Usb150LateDiag" not in s:
    print("patch_usb160: FATAL pristine keys150 menu block not found")
    sys.exit(1)

NEW_FB = r'''STATIC
VOID
ForceLoadSimpleFb (
  VOID
  )
{
  //
  // keys160: SimpleFb LoadImage/StartImage intentionally disabled (text UI only).
  //
  if (mFbLoadTried) {
    return;
  }
  mFbLoadTried = TRUE;
  Say (L"  [UI160] SimpleFb load disabled (keys160)");
}

'''

NEW_GADGET = r'''//
// ============================ keys160: minimal EP0 ==========================
//
// DWC3 device-mode registers (same map used by keys158 / the reference impl).
//
#define USB160_BASE          0x0A600000
#define USB160_GSNPSID       0x0C120
#define USB160_GEVNTADRLO    0x0C400
#define USB160_GEVNTADRHI    0x0C404
#define USB160_GEVNTSIZ      0x0C408
#define USB160_GEVNTCOUNT    0x0C40C
#define USB160_GCTL          0x0C110
#define USB160_GSTS          0x0C118
#define USB160_GUSB2PHYCFG   0x0C200
#define USB160_DCFG          0x0C700
#define USB160_DCTL          0x0C704
#define USB160_DEVTEN        0x0C708
#define USB160_DSTS          0x0C70C
#define USB160_DALEPENA      0x0C720
#define USB160_DEPCMDPAR2(n) (0x0C800 + 0x10 * (n))
#define USB160_DEPCMDPAR1(n) (0x0C804 + 0x10 * (n))
#define USB160_DEPCMDPAR0(n) (0x0C808 + 0x10 * (n))
#define USB160_DEPCMD(n)     (0x0C80C + 0x10 * (n))

#define USB160_DCTL_RUN_STOP   (1U << 31)
#define USB160_DCTL_CSFTRST    (1U << 30)
#define USB160_DSTS_DEVCTRLHLT (1U << 22)
#define USB160_PHYCFG_CLEAR    ((1U << 31) | (1U << 8) | (1U << 6))

#define USB160_DEPCMD_SETEPCONFIG       1
#define USB160_DEPCMD_SETTRANSFRESOURCE 2
#define USB160_DEPCMD_SETSTALL          4
#define USB160_DEPCMD_STARTTRANSFER     6
#define USB160_DEPCMD_DEPSTARTCFG       9
#define USB160_DEPCMD_CMDACT            (1U << 10)

#define USB160_TRB_HWO      (1U << 0)
#define USB160_TRB_LST      (1U << 1)
#define USB160_TRB_ISP_IMI  (1U << 10)
#define USB160_TRB_IOC      (1U << 11)
#define USB160_TRBCTL_SETUP   (2U << 4)
#define USB160_TRBCTL_STATUS2 (3U << 4)
#define USB160_TRBCTL_STATUS3 (4U << 4)
#define USB160_TRBCTL_DATA    (5U << 4)

// DMA area layout inside one 16 KiB allocation.
#define USB160_EVT        0x0000
#define USB160_EVT_SIZE   0x1000
#define USB160_TRB_OUT    0x1000
#define USB160_TRB_IN     0x1010
#define USB160_SETUP      0x1040
#define USB160_DATA       0x1100
#define USB160_DMA_SIZE   0x4000

// Control-transfer states.
#define USB160_ST_SETUP        0
#define USB160_ST_DATA         1
#define USB160_ST_WAIT_STATUS2 2
#define USB160_ST_WAIT_STATUS3 3
#define USB160_ST_STATUS       4

#define USB160_MAX_STR 126

STATIC UINT8   *mUsb160Dma;
STATIC UINTN    mUsb160EvtPos;
STATIC UINT32   mUsb160State;
STATIC BOOLEAN  mUsb160DataIn;
STATIC UINT32   mUsb160Events;
STATIC BOOLEAN  mUsb160Ready;
STATIC UINT32   mUsb160SetupCount;
STATIC UINT32   mUsb160DescCount;
STATIC UINT32   mUsb160DepLogs;
STATIC UINT32   mUsb160RawLogs;
STATIC UINT32   mUsb160LastDsts;
STATIC UINT32   mUsb160LastCount;

STATIC UINT32
Usb160Rd (
  IN UINTN  Off
  )
{
  return *(volatile UINT32 *)(UINTN)(USB160_BASE + Off);
}

STATIC VOID
Usb160Wr (
  IN UINTN   Off,
  IN UINT32  Value
  )
{
  *(volatile UINT32 *)(UINTN)(USB160_BASE + Off) = Value;
  __asm__ __volatile__ ("dsb sy" ::: "memory");
}

STATIC VOID
Usb160Clean (
  IN UINTN  Address,
  IN UINTN  Length
  )
{
  UINTN  Line;

  for (Line = Address & ~((UINTN)0x3F); Line < Address + Length; Line += 0x40) {
    __asm__ __volatile__ ("dc cvac, %0" :: "r" (Line) : "memory");
  }
  __asm__ __volatile__ ("dsb sy" ::: "memory");
}

STATIC VOID
Usb160Inval (
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
Usb160Print (
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

STATIC EFI_STATUS
Usb160EpCmd (
  IN UINT32  Ep,
  IN UINT32  Cmd,
  IN UINT32  Param0,
  IN UINT32  Param1,
  IN UINT32  Param2
  )
{
  UINTN   I;
  UINT32  Value;

  Usb160Wr (USB160_DEPCMDPAR2 (Ep), Param2);
  Usb160Wr (USB160_DEPCMDPAR1 (Ep), Param1);
  Usb160Wr (USB160_DEPCMDPAR0 (Ep), Param0);
  Usb160Wr (USB160_DEPCMD (Ep), Cmd | USB160_DEPCMD_CMDACT);

  for (I = 0; I < 200; I++) {
    Value = Usb160Rd (USB160_DEPCMD (Ep));
    if ((Value & USB160_DEPCMD_CMDACT) == 0) {
      if (mUsb160DepLogs++ < 80) {
        Usb160Print (L"  [USB160] dep n=%u cmd=%02x ok=%u status=%x p0=%08x",
                     Ep, Cmd & 0xF, (((Value >> 12) & 0xF) == 0) ? 1 : 0,
                     (Value >> 12) & 0xF, Param0);
      }
      if (((Value >> 12) & 0xF) != 0) {
        return EFI_DEVICE_ERROR;
      }
      return EFI_SUCCESS;
    }
    gBS->Stall (10);
  }
  if (mUsb160DepLogs++ < 80) {
    Usb160Print (L"  [USB160] dep n=%u cmd=%02x timeout p0=%08x", Ep, Cmd & 0xF, Param0);
  }
  return EFI_TIMEOUT;
}

STATIC VOID
Usb160Start (
  IN UINT32  Ep,
  IN UINTN   BufOff,
  IN UINT32  Length,
  IN UINT32  Ctl
  )
{
  volatile UINT32  *Trb;
  UINT64           BufPa;
  UINT64           TrbPa;

  Trb   = (volatile UINT32 *)(UINTN)(mUsb160Dma + (Ep ? USB160_TRB_IN : USB160_TRB_OUT));
  BufPa = (UINT64)(UINTN)(mUsb160Dma + BufOff);
  Trb[0] = (UINT32)BufPa;
  Trb[1] = (UINT32)(BufPa >> 32);
  Trb[2] = Length;
  Trb[3] = Ctl | USB160_TRB_HWO | USB160_TRB_LST | USB160_TRB_ISP_IMI | USB160_TRB_IOC;
  Usb160Clean ((UINTN)Trb, 16);
  if (Length != 0) {
    Usb160Clean ((UINTN)(mUsb160Dma + BufOff), Length);
  }
  TrbPa = (UINT64)(UINTN)Trb;
  Usb160EpCmd (Ep, USB160_DEPCMD_STARTTRANSFER, 0, (UINT32)TrbPa, (UINT32)(TrbPa >> 32));
}

STATIC VOID
Usb160ArmSetup (
  VOID
  )
{
  mUsb160State = USB160_ST_SETUP;
  Usb160Start (0, USB160_SETUP, 8, USB160_TRBCTL_SETUP);
}

STATIC VOID
Usb160Stall (
  VOID
  )
{
  Usb160EpCmd (0, USB160_DEPCMD_SETSTALL, 0, 0, 0);
  Usb160ArmSetup ();
}

STATIC CONST UINT8  mUsb160DevDesc[18] = {
  18, 1, 0x00, 0x02, 0x00, 0x00, 0x00, 64,
  0x09, 0x12, 0x01, 0xC1, 0x00, 0x01, 1, 2, 3, 1
};

STATIC CONST UINT8  mUsb160CfgDesc[18] = {
  9, 2, 18, 0, 1, 1, 0, 0x80, 250,
  9, 4, 0, 0, 0, 0xFF, 0x00, 0x00, 0
};

STATIC CONST CHAR8  *mUsb160Strings[3] = {
  NULL, "Vermeer", "K70 UEFI DEBUG"
};

STATIC UINT32
Usb160String (
  IN  UINT32  Index,
  OUT UINT8   *Out
  )
{
  CONST CHAR8  *Str;
  UINT32       N;

  if (Index == 0) {
    Out[0] = 4; Out[1] = 3; Out[2] = 0x09; Out[3] = 0x04;
    return 4;
  }
  if (Index > 2) {
    return 0;
  }
  Str = mUsb160Strings[Index];
  N = 2;
  while ((*Str != 0) && (N < USB160_MAX_STR)) {
    Out[N++] = (UINT8)*Str++;
    Out[N++] = 0;
  }
  Out[0] = (UINT8)N;
  Out[1] = 3;
  return N;
}

STATIC VOID
Usb160Setup (
  VOID
  )
{
  CONST UINT8  *St;
  UINT8        *Data;
  UINT8         Type;
  UINT8         Req;
  UINT16        Value;
  UINT16        Length;
  UINT32        N;
  BOOLEAN       Ok;
  UINT32        Dcfg;

  St     = (CONST UINT8 *)(UINTN)(mUsb160Dma + USB160_SETUP);
  Data   = (UINT8 *)(UINTN)(mUsb160Dma + USB160_DATA);
  Type   = St[0];
  Req    = St[1];
  Value  = (UINT16)(St[2] | (St[3] << 8));
  Length = (UINT16)(St[6] | (St[7] << 8));
  N      = 0;
  Ok     = TRUE;

  mUsb160SetupCount++;
  if (mUsb160SetupCount <= 40) {
    Usb160Print (L"  [USB160] setup bm=%02x b=%02x wv=%04x wi=%04x wl=%04x",
                 Type, Req, Value,
                 (UINT16)(St[4] | (St[5] << 8)), Length);
  }
  mUsb160DataIn = ((Type & 0x80) != 0);

  if ((Type & 0x60) != 0) {
    Ok = FALSE;                       // only standard requests
  } else if (Req == 6) {             // GET_DESCRIPTOR
    switch ((UINT8)(Value >> 8)) {
    case 1:
      CopyMem (Data, mUsb160DevDesc, sizeof (mUsb160DevDesc));
      N = sizeof (mUsb160DevDesc);
      break;
    case 2:
      CopyMem (Data, mUsb160CfgDesc, sizeof (mUsb160CfgDesc));
      N = sizeof (mUsb160CfgDesc);
      break;
    case 3:
      N = Usb160String (Value & 0xFF, Data);
      Ok = (N != 0);
      break;
    default:
      Ok = FALSE;
      break;
    }
    if (Ok && (mUsb160DescCount++ < 40)) {
      Usb160Print (L"  [USB160] desc type=%02x len=%u", (UINT8)(Value >> 8), N);
    }
  } else if (Req == 5) {             // SET_ADDRESS
    Dcfg = Usb160Rd (USB160_DCFG) & ~(0x7FU << 3);
    Usb160Wr (USB160_DCFG, Dcfg | ((UINT32)(Value & 0x7F) << 3));
    Usb160Print (L"  [USB160] address=%u", Value & 0x7F);
  } else if (Req == 9) {             // SET_CONFIGURATION
    Usb160Print (L"  [USB160] configured=%u", Value);
  } else if (Req == 8) {             // GET_CONFIGURATION
    Data[0] = 1;
    N = 1;
  } else if (Req == 0) {             // GET_STATUS
    Data[0] = 0;
    Data[1] = 0;
    N = 2;
  } else if (Req == 11) {            // SET_INTERFACE
    // nothing to do
  } else {
    Ok = FALSE;
  }

  if (!Ok) {
    Usb160Print (L"  [USB160] stall b=%02x", Req);
    Usb160Stall ();
    return;
  }
  if (Length == 0) {
    mUsb160State = USB160_ST_WAIT_STATUS2;
    return;
  }
  mUsb160State = USB160_ST_DATA;
  if (mUsb160DataIn) {
    if (N > Length) {
      N = Length;
    }
    Usb160Start (1, USB160_DATA, N, USB160_TRBCTL_DATA);
  } else {
    Usb160Start (0, USB160_DATA, 64, USB160_TRBCTL_DATA);
  }
}

STATIC VOID
Usb160Event (
  IN UINT32  Ev
  )
{
  UINT32  Type;
  UINT32  Ep;
  UINT32  EvType;
  UINT32  Status;
  UINT32  Speed;
  UINT32  Dcfg;

  if ((Ev & 1) != 0) {               // device event
    Type = (Ev >> 8) & 0xF;
    if (Type == 1) {                 // USB reset
      Dcfg = Usb160Rd (USB160_DCFG) & ~(0x7FU << 3);
      Usb160Wr (USB160_DCFG, Dcfg);
      Usb160Print (L"  [USB160] bus reset");
    } else if (Type == 2) {          // connect done: EP0 max packet 64
      Speed = Usb160Rd (USB160_DSTS) & 7;
      Usb160EpCmd (0, USB160_DEPCMD_SETEPCONFIG, (0U << 1) | (64U << 3) | (2U << 30),
                   (1U << 8) | (1U << 10) | (0U << 25), 0);
      Usb160EpCmd (1, USB160_DEPCMD_SETEPCONFIG, (0U << 1) | (64U << 3) | (2U << 30),
                   (1U << 8) | (1U << 10) | (1U << 25), 0);
      Usb160Print (L"  [USB160] connect done speed=%u", Speed);
    } else if (Type == 0) {          // disconnect
      Usb160Print (L"  [USB160] disconnect");
    }
    return;
  }

  Ep     = (Ev >> 1) & 0x1F;
  EvType = (Ev >> 6) & 0xF;
  Status = (Ev >> 12) & 0xF;
  if (Ep > 1) {
    return;
  }

  if (EvType == 1) {                 // XferComplete
    switch (mUsb160State) {
    case USB160_ST_SETUP:
      Usb160Inval ((UINTN)(mUsb160Dma + USB160_SETUP), 8);
      Usb160Setup ();
      break;
    case USB160_ST_DATA:
      mUsb160State = USB160_ST_WAIT_STATUS3;
      break;
    case USB160_ST_STATUS:
      Usb160ArmSetup ();
      break;
    default:
      break;
    }
    return;
  }

  if ((EvType == 3) && (Status == 2)) {  // XferNotReady, control status phase
    if ((mUsb160State == USB160_ST_WAIT_STATUS2) || (mUsb160State == USB160_ST_WAIT_STATUS3)) {
      UINT32 Ctl = (mUsb160State == USB160_ST_WAIT_STATUS3) ? USB160_TRBCTL_STATUS3 : USB160_TRBCTL_STATUS2;
      mUsb160State = USB160_ST_STATUS;
      Usb160Start (Ep, USB160_DATA, 0, Ctl);
    }
  }
}

STATIC VOID
Usb160Poll (
  VOID
  )
{
  UINT32  Count;
  UINT32  Done;
  UINT32  Ev;

  if (!mUsb160Ready) {
    return;
  }
  Count = Usb160Rd (USB160_GEVNTCOUNT) & 0xFFFF;
  if (Count == 0) {
    return;
  }
  Usb160Inval ((UINTN)(mUsb160Dma + USB160_EVT), USB160_EVT_SIZE);
  for (Done = 0; Done + 4 <= Count; Done += 4) {
    Ev = *(volatile UINT32 *)(UINTN)(mUsb160Dma + USB160_EVT + mUsb160EvtPos);
    mUsb160EvtPos = (mUsb160EvtPos + 4) % USB160_EVT_SIZE;
    mUsb160Events++;
    if (mUsb160RawLogs < 8) {
      mUsb160RawLogs++;
      if ((Ev & 1) != 0) {
        Usb160Print (L"  [USB160] evt raw=%08x type=%u ep=dev", Ev, (Ev >> 8) & 0xF);
      } else {
        Usb160Print (L"  [USB160] evt raw=%08x type=%u ep=%u", Ev, (Ev >> 6) & 0xF, (Ev >> 1) & 0x1F);
      }
    } else if (mUsb160Events <= 60) {
      Usb160Print (L"  [USB160] evt=%08x", Ev);
    }
    Usb160Event (Ev);
  }
  Usb160Wr (USB160_GEVNTCOUNT, Count);   // write back to clear
}

STATIC VOID
Usb160Stat (
  VOID
  )
{
  UINT32  Dsts;
  UINT32  Count;
  UINT32  Dcfg;

  Dsts  = Usb160Rd (USB160_DSTS);
  Count = Usb160Rd (USB160_GEVNTCOUNT) & 0xFFFF;
  Dcfg  = Usb160Rd (USB160_DCFG);
  Usb160Print (L"  [USB160] poll: DSTS=%08x hlt22=%d spd=%u evtcnt=%08x",
               Dsts, (Dsts >> 22) & 1, Dsts & 7, Count);
  if ((Dsts != mUsb160LastDsts) || (Count != mUsb160LastCount)) {
    mUsb160LastDsts  = Dsts;
    mUsb160LastCount = Count;
    Usb160Print (L"  [USB160] regs: DCFG=%08x devspd=%u devaddr=%u DALEPENA=%08x",
                 Dcfg, Dcfg & 7, (Dcfg >> 3) & 0x7F, Usb160Rd (USB160_DALEPENA));
    Usb160Print (L"  [USB160] regs2: DEVTEN=%08x DCTL=%08x PHYCFG=%08x GEVNTSIZ=%08x",
                 Usb160Rd (USB160_DEVTEN), Usb160Rd (USB160_DCTL),
                 Usb160Rd (USB160_GUSB2PHYCFG), Usb160Rd (USB160_GEVNTSIZ));
    Usb160Print (L"  [USB160] regs3: DEPCMD0=%08x PAR0(0)=%08x evtaddr=%08x%08x",
                 Usb160Rd (USB160_DEPCMD (0)), Usb160Rd (USB160_DEPCMDPAR0 (0)),
                 Usb160Rd (USB160_GEVNTADRHI), Usb160Rd (USB160_GEVNTADRLO));
  }
}

STATIC VOID
Usb160Init (
  VOID
  )
{
  EFI_PHYSICAL_ADDRESS  DmaPa;
  EFI_STATUS            Status;
  UINTN                 I;
  UINT32                Gsnpsid;
  UINT32                Dsts;

  Status = gBS->AllocatePages (AllocateAnyPages, EfiBootServicesData, USB160_DMA_SIZE / 0x1000, &DmaPa);
  if (EFI_ERROR (Status)) {
    Say (L"  [USB160] FATAL: no DMA pages");
    return;
  }
  mUsb160Dma = (UINT8 *)(UINTN)DmaPa;
  ZeroMem (mUsb160Dma, USB160_DMA_SIZE);
  Usb160Print (L"  [USB160] dma=%08x%08x (16 KiB)", (UINT32)(((UINT64)(UINTN)mUsb160Dma) >> 32),
               (UINT32)(UINTN)mUsb160Dma);

  //
  // 1) Device soft reset (PHY / clocks stay as XBL-BL left them).
  //
  Usb160Wr (USB160_DCTL, USB160_DCTL_CSFTRST);
  for (I = 0; (I < 500) && ((Usb160Rd (USB160_DCTL) & USB160_DCTL_CSFTRST) != 0); I++) {
    gBS->Stall (1000);
  }
  Usb160Print (L"  [USB160] soft reset done after %u ms DCTL=%08x GCTL=%08x",
               (UINT32)I, Usb160Rd (USB160_DCTL), Usb160Rd (USB160_GCTL));
  if ((Usb160Rd (USB160_DCTL) & USB160_DCTL_CSFTRST) != 0) {
    Say (L"  [USB160] FATAL: soft reset stuck");
    return;
  }

  //
  // 1b) CSFTRST restores the PHY-suspend defaults: clear SUSPHY / ENBLSLPM / PHYSOFTRST
  //     again and give the PHY 20 ms to settle before touching endpoints.
  //
  Usb160Wr (USB160_GUSB2PHYCFG, Usb160Rd (USB160_GUSB2PHYCFG) & ~USB160_PHYCFG_CLEAR);
  gBS->Stall (20000);
  Usb160Print (L"  [USB160] phycfg=%08x gctl=%08x", Usb160Rd (USB160_GUSB2PHYCFG),
               Usb160Rd (USB160_GCTL));

  //
  // 2) Event buffer, interrupt masked (bit31), polled from the resident loop.
  //
  Usb160Wr (USB160_GEVNTADRLO, (UINT32)(UINTN)mUsb160Dma);
  Usb160Wr (USB160_GEVNTADRHI, (UINT32)(((UINT64)(UINTN)mUsb160Dma) >> 32));
  Usb160Wr (USB160_GEVNTSIZ,   USB160_EVT_SIZE);
  Usb160Wr (USB160_GEVNTCOUNT, Usb160Rd (USB160_GEVNTCOUNT) & 0xFFFF);
  mUsb160EvtPos = 0;
  Usb160Print (L"  [USB160] evt: addr=%08x%08x siz=%08x cnt=%08x",
               Usb160Rd (USB160_GEVNTADRHI), Usb160Rd (USB160_GEVNTADRLO),
               Usb160Rd (USB160_GEVNTSIZ), Usb160Rd (USB160_GEVNTCOUNT));

  //
  // 3) High speed, address 0; device events: disconnect / USB reset / connect done.
  //
  Usb160Wr (USB160_DCFG, Usb160Rd (USB160_DCFG) & ~(7U | (0x7FU << 3)));
  Usb160Wr (USB160_DEVTEN, 0x7);

  //
  // 4) EP0 OUT (dep 0) and EP0 IN (dep 1), control type, mps 512 for now.
  //
  Usb160EpCmd (0, USB160_DEPCMD_DEPSTARTCFG, 0, 0, 0);
  Usb160EpCmd (0, USB160_DEPCMD_SETEPCONFIG, (0U << 1) | (512U << 3),
               (1U << 8) | (1U << 10) | (0U << 25), 0);
  Usb160EpCmd (0, USB160_DEPCMD_SETTRANSFRESOURCE, 1, 0, 0);
  Usb160EpCmd (1, USB160_DEPCMD_SETEPCONFIG, (0U << 1) | (512U << 3),
               (1U << 8) | (1U << 10) | (1U << 25), 0);
  Usb160EpCmd (1, USB160_DEPCMD_SETTRANSFRESOURCE, 1, 0, 0);
  Usb160Wr (USB160_DALEPENA, 0x3);

  //
  // 5) Run first, then arm the SETUP TRB once the controller reports not-halted
  //    (Linux dwc3 arms ep0 transfers only after the core is running).
  //
  Usb160Wr (USB160_DCTL, Usb160Rd (USB160_DCTL) | USB160_DCTL_RUN_STOP);
  for (I = 0; (I < 500) && ((Usb160Rd (USB160_DSTS) & USB160_DSTS_DEVCTRLHLT) != 0); I++) {
    gBS->Stall (1000);
  }
  mUsb160State = USB160_ST_SETUP;
  Usb160ArmSetup ();
  Dsts    = Usb160Rd (USB160_DSTS);
  Gsnpsid = Usb160Rd (USB160_GSNPSID);
  mUsb160Ready = TRUE;
  Usb160Print (L"  [USB160] gadget up: GSNPSID=%08x GCTL=%08x DCFG=%08x DEVTEN=%08x",
               Gsnpsid, Usb160Rd (USB160_GCTL), Usb160Rd (USB160_DCFG),
               Usb160Rd (USB160_DEVTEN));
  Usb160Print (L"  [USB160] up2: DALEPENA=%08x DSTS=%08x hlt22=%d spd=%u",
               Usb160Rd (USB160_DALEPENA), Dsts, (Dsts >> 22) & 1, Dsts & 7);
}

'''

c = s.find("STATIC\nVOID\nForceLoadSimpleFb (\n")
if c < 0:
    print("patch_usb160: FATAL ForceLoadSimpleFb not found")
    sys.exit(1)
d = s.find("STATIC\nVOID\nProbeGop (\n", c)
if d < 0:
    print("patch_usb160: FATAL ProbeGop not found")
    sys.exit(1)
s = s[:c] + NEW_FB + s[d:]

a = s.find("STATIC UINT32\nUsb150Rd (\n")
if a < 0:
    print("patch_usb160: FATAL Usb150Rd block not found")
    sys.exit(1)
b = s.find("EFI_STATUS\nEFIAPI\nVermeerMenuDxeEntry", a)
if b < 0:
    print("patch_usb160: FATAL entry not found")
    sys.exit(1)
s = s[:a] + NEW_GADGET + s[b:]

a = s.find('  Say (L"  [MENU150] console stays on, USB150 diag then photo halt");')
if a < 0:
    print("patch_usb160: FATAL MENU150 entry tail not found")
    sys.exit(1)
b = s.find("  CpuDeadLoop ();", a)
if b < 0:
    print("patch_usb160: FATAL CpuDeadLoop not found")
    sys.exit(1)
b += len("  CpuDeadLoop ();")

NEW_TAIL = '''  Say (L"  [MENU160] minimal EP0 gadget: polling event buffer, staying enumerated");
  {
    STATIC UINTN  mGuiDisabled160 = 0;
    STATIC UINTN  mTicks160       = 0;
    EFI_INPUT_KEY Key;
    BOOLEAN       Got;

    Usb160Init ();
    for (;;) {
      Usb160Poll ();
      if ((mTicks160 % 1000) == 0) {
        Usb160Stat ();
      }
      if ((mTicks160 % 5000) == 0) {
        Say (L"  [USB160] alive");
      }
      mTicks160++;
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
    Say (L"  [MENU160] key pressed, leaving resident loop");
    if (mGuiDisabled160 == 0) {
      RunMenu ();
    }
  }
  Say (L"  [MENU160] done, returning to BDS");'''

s = s[:a] + NEW_TAIL + s[b:]

# ---- sanity -----------------------------------------------------------------
for bad in ("Usb150Wr (", "Usb150Rd (", "Usb150Dump (", "Usb150LateDiag", "CpuDeadLoop ()",
            "0x0010F004", "0x0010F000", "0x0A6F8800"):
    if bad in s:
        print("patch_usb160: FATAL still contains %r" % bad)
        sys.exit(1)
for need in ("[MENU160]", "[USB160]", "Usb160Init", "Usb160Poll", "Usb160Stat", "RunMenu ()",
             "USB160_DEPCMD_STARTTRANSFER", "mUsb160CfgDesc", "K70 UEFI DEBUG"):
    if need not in s:
        print("patch_usb160: FATAL missing %r" % need)
        sys.exit(1)

P.write_text(s, encoding="utf-8")
print("patch_usb160: Menu -> minimal DWC3 EP0 gadget (polled events, 1 cfg, no CDC/MSD)")
print("PATCH_USB160 OK")
