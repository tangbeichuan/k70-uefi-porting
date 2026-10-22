#!/usr/bin/env python3
"""patch_usb161b.py (keys161b: minimal-write variant) -- keys161b: minimal DWC3 device-mode EP0 gadget WITHOUT CSFTRST.

Baseline: pristine keys149 Menu (same source patch_usb157.py starts from), so
this replaces the keys150 diag block and the entry tail exactly like
patch_usb157.py does, but instead of a read-only monitor it installs:

  * a 16 KiB page-aligned DMA area (AllocatePages);
  * NO device soft reset (DCTL.CSFTRST removed: it resets the PHY/clocks domain);
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

Idempotent via the "[MENU161b]" marker.
"""
import pathlib
import sys

P = pathlib.Path("/root/k70/uefi/Platforms/Xiaomi/vermeerPkg/Drivers/VermeerMenuDxe/VermeerMenuDxe.c")
s = P.read_text(encoding="utf-8")

if "[MENU161b]" in s:
    print("patch_usb161b: already patched")
    sys.exit(0)

if "[MENU150]" not in s or "Usb150LateDiag" not in s:
    print("patch_usb161b: FATAL pristine keys150 menu block not found")
    sys.exit(1)

NEW_FB = r'''STATIC
VOID
ForceLoadSimpleFb (
  VOID
  )
{
  //
  // keys161b: SimpleFb LoadImage/StartImage intentionally disabled (text UI only).
  //
  if (mFbLoadTried) {
    return;
  }
  mFbLoadTried = TRUE;
  Say (L"  [UI161b] SimpleFb load disabled (keys161b)");
}

'''

NEW_GADGET = r'''//
// ============================ keys161b: minimal EP0 ==========================
//
// DWC3 device-mode registers (same map used by keys158 / the reference impl).
//
#define USB161b_BASE          0x0A600000
#define USB161b_GSNPSID       0x0C120
#define USB161b_GEVNTADRLO    0x0C400
#define USB161b_GEVNTADRHI    0x0C404
#define USB161b_GEVNTSIZ      0x0C408
#define USB161b_GEVNTCOUNT    0x0C40C
#define USB161b_GCTL          0x0C110
#define USB161b_GSTS          0x0C118
#define USB161b_GUSB2PHYCFG   0x0C200
#define USB161b_DCFG          0x0C700
#define USB161b_DCTL          0x0C704
#define USB161b_DEVTEN        0x0C708
#define USB161b_DSTS          0x0C70C
#define USB161b_DALEPENA      0x0C720
#define USB161b_DEPCMDPAR2(n) (0x0C800 + 0x10 * (n))
#define USB161b_DEPCMDPAR1(n) (0x0C804 + 0x10 * (n))
#define USB161b_DEPCMDPAR0(n) (0x0C808 + 0x10 * (n))
#define USB161b_DEPCMD(n)     (0x0C80C + 0x10 * (n))

#define USB161b_DCTL_RUN_STOP   (1U << 31)
#define USB161b_DCTL_CSFTRST    (1U << 30)
#define USB161b_DSTS_DEVCTRLHLT (1U << 22)
#define USB161b_PHYCFG_CLEAR    ((1U << 8) | (1U << 6))

#define USB161b_DEPCMD_SETEPCONFIG       1
#define USB161b_DEPCMD_SETTRANSFRESOURCE 2
#define USB161b_DEPCMD_SETSTALL          4
#define USB161b_DEPCMD_STARTTRANSFER     6
#define USB161b_DEPCMD_DEPSTARTCFG       9
#define USB161b_DEPCMD_CMDACT            (1U << 10)

#define USB161b_TRB_HWO      (1U << 0)
#define USB161b_TRB_LST      (1U << 1)
#define USB161b_TRB_ISP_IMI  (1U << 10)
#define USB161b_TRB_IOC      (1U << 11)
#define USB161b_TRBCTL_SETUP   (2U << 4)
#define USB161b_TRBCTL_STATUS2 (3U << 4)
#define USB161b_TRBCTL_STATUS3 (4U << 4)
#define USB161b_TRBCTL_DATA    (5U << 4)

// DMA area layout inside one 16 KiB allocation.
#define USB161b_EVT        0x0000
#define USB161b_EVT_SIZE   0x1000
#define USB161b_TRB_OUT    0x1000
#define USB161b_TRB_IN     0x1010
#define USB161b_SETUP      0x1040
#define USB161b_DATA       0x1100
#define USB161b_DMA_SIZE   0x4000

// Control-transfer states.
#define USB161b_ST_SETUP        0
#define USB161b_ST_DATA         1
#define USB161b_ST_WAIT_STATUS2 2
#define USB161b_ST_WAIT_STATUS3 3
#define USB161b_ST_STATUS       4

#define USB161b_MAX_STR 126

STATIC UINT8   *mUsb161bDma;
STATIC UINTN    mUsb161bEvtPos;
STATIC UINT32   mUsb161bState;
STATIC BOOLEAN  mUsb161bDataIn;
STATIC UINT32   mUsb161bEvents;
STATIC BOOLEAN  mUsb161bReady;
STATIC UINT32   mUsb161bSetupCount;
STATIC UINT32   mUsb161bDescCount;
STATIC UINT32   mUsb161bDepLogs;
STATIC UINT32   mUsb161bRawLogs;
STATIC UINT32   mUsb161bLastDsts;
STATIC UINT32   mUsb161bLastCount;

STATIC UINT32
Usb161bRd (
  IN UINTN  Off
  )
{
  return *(volatile UINT32 *)(UINTN)(USB161b_BASE + Off);
}

STATIC VOID
Usb161bWr (
  IN UINTN   Off,
  IN UINT32  Value
  )
{
  *(volatile UINT32 *)(UINTN)(USB161b_BASE + Off) = Value;
  __asm__ __volatile__ ("dsb sy" ::: "memory");
}

STATIC VOID
Usb161bClean (
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
Usb161bInval (
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
Usb161bPrint (
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
Usb161bEpCmd (
  IN UINT32  Ep,
  IN UINT32  Cmd,
  IN UINT32  Param0,
  IN UINT32  Param1,
  IN UINT32  Param2
  )
{
  UINTN   I;
  UINT32  Value;

  Usb161bWr (USB161b_DEPCMDPAR2 (Ep), Param2);
  Usb161bWr (USB161b_DEPCMDPAR1 (Ep), Param1);
  Usb161bWr (USB161b_DEPCMDPAR0 (Ep), Param0);
  Usb161bWr (USB161b_DEPCMD (Ep), Cmd | USB161b_DEPCMD_CMDACT);

  for (I = 0; I < 200; I++) {
    Value = Usb161bRd (USB161b_DEPCMD (Ep));
    if ((Value & USB161b_DEPCMD_CMDACT) == 0) {
      if (mUsb161bDepLogs++ < 80) {
        Usb161bPrint (L"  [USB161b] dep n=%u cmd=%02x ok=%u status=%x p0=%08x",
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
  if (mUsb161bDepLogs++ < 80) {
    Usb161bPrint (L"  [USB161b] dep n=%u cmd=%02x timeout p0=%08x", Ep, Cmd & 0xF, Param0);
  }
  return EFI_TIMEOUT;
}

STATIC VOID
Usb161bStart (
  IN UINT32  Ep,
  IN UINTN   BufOff,
  IN UINT32  Length,
  IN UINT32  Ctl
  )
{
  volatile UINT32  *Trb;
  UINT64           BufPa;
  UINT64           TrbPa;

  Trb   = (volatile UINT32 *)(UINTN)(mUsb161bDma + (Ep ? USB161b_TRB_IN : USB161b_TRB_OUT));
  BufPa = (UINT64)(UINTN)(mUsb161bDma + BufOff);
  Trb[0] = (UINT32)BufPa;
  Trb[1] = (UINT32)(BufPa >> 32);
  Trb[2] = Length;
  Trb[3] = Ctl | USB161b_TRB_HWO | USB161b_TRB_LST | USB161b_TRB_ISP_IMI | USB161b_TRB_IOC;
  Usb161bClean ((UINTN)Trb, 16);
  if (Length != 0) {
    Usb161bClean ((UINTN)(mUsb161bDma + BufOff), Length);
  }
  TrbPa = (UINT64)(UINTN)Trb;
  Usb161bEpCmd (Ep, USB161b_DEPCMD_STARTTRANSFER, 0, (UINT32)TrbPa, (UINT32)(TrbPa >> 32));
}

STATIC VOID
Usb161bArmSetup (
  VOID
  )
{
  mUsb161bState = USB161b_ST_SETUP;
  Usb161bStart (0, USB161b_SETUP, 8, USB161b_TRBCTL_SETUP);
}

STATIC VOID
Usb161bStall (
  VOID
  )
{
  Usb161bEpCmd (0, USB161b_DEPCMD_SETSTALL, 0, 0, 0);
  Usb161bArmSetup ();
}

STATIC CONST UINT8  mUsb161bDevDesc[18] = {
  18, 1, 0x00, 0x02, 0x00, 0x00, 0x00, 64,
  0x09, 0x12, 0x01, 0xC1, 0x00, 0x01, 1, 2, 3, 1
};

STATIC CONST UINT8  mUsb161bCfgDesc[18] = {
  9, 2, 18, 0, 1, 1, 0, 0x80, 250,
  9, 4, 0, 0, 0, 0xFF, 0x00, 0x00, 0
};

STATIC CONST CHAR8  *mUsb161bStrings[3] = {
  NULL, "Vermeer", "K70 UEFI DEBUG"
};

STATIC UINT32
Usb161bString (
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
  Str = mUsb161bStrings[Index];
  N = 2;
  while ((*Str != 0) && (N < USB161b_MAX_STR)) {
    Out[N++] = (UINT8)*Str++;
    Out[N++] = 0;
  }
  Out[0] = (UINT8)N;
  Out[1] = 3;
  return N;
}

STATIC VOID
Usb161bSetup (
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

  St     = (CONST UINT8 *)(UINTN)(mUsb161bDma + USB161b_SETUP);
  Data   = (UINT8 *)(UINTN)(mUsb161bDma + USB161b_DATA);
  Type   = St[0];
  Req    = St[1];
  Value  = (UINT16)(St[2] | (St[3] << 8));
  Length = (UINT16)(St[6] | (St[7] << 8));
  N      = 0;
  Ok     = TRUE;

  mUsb161bSetupCount++;
  if (mUsb161bSetupCount <= 40) {
    Usb161bPrint (L"  [USB161b] setup bm=%02x b=%02x wv=%04x wi=%04x wl=%04x",
                 Type, Req, Value,
                 (UINT16)(St[4] | (St[5] << 8)), Length);
  }
  mUsb161bDataIn = ((Type & 0x80) != 0);

  if ((Type & 0x60) != 0) {
    Ok = FALSE;                       // only standard requests
  } else if (Req == 6) {             // GET_DESCRIPTOR
    switch ((UINT8)(Value >> 8)) {
    case 1:
      CopyMem (Data, mUsb161bDevDesc, sizeof (mUsb161bDevDesc));
      N = sizeof (mUsb161bDevDesc);
      break;
    case 2:
      CopyMem (Data, mUsb161bCfgDesc, sizeof (mUsb161bCfgDesc));
      N = sizeof (mUsb161bCfgDesc);
      break;
    case 3:
      N = Usb161bString (Value & 0xFF, Data);
      Ok = (N != 0);
      break;
    default:
      Ok = FALSE;
      break;
    }
    if (Ok && (mUsb161bDescCount++ < 40)) {
      Usb161bPrint (L"  [USB161b] desc type=%02x len=%u", (UINT8)(Value >> 8), N);
    }
  } else if (Req == 5) {             // SET_ADDRESS
    Dcfg = Usb161bRd (USB161b_DCFG) & ~(0x7FU << 3);
    Usb161bWr (USB161b_DCFG, Dcfg | ((UINT32)(Value & 0x7F) << 3));
    Usb161bPrint (L"  [USB161b] address=%u", Value & 0x7F);
  } else if (Req == 9) {             // SET_CONFIGURATION
    Usb161bPrint (L"  [USB161b] configured=%u", Value);
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
    Usb161bPrint (L"  [USB161b] stall b=%02x", Req);
    Usb161bStall ();
    return;
  }
  if (Length == 0) {
    mUsb161bState = USB161b_ST_WAIT_STATUS2;
    return;
  }
  mUsb161bState = USB161b_ST_DATA;
  if (mUsb161bDataIn) {
    if (N > Length) {
      N = Length;
    }
    Usb161bStart (1, USB161b_DATA, N, USB161b_TRBCTL_DATA);
  } else {
    Usb161bStart (0, USB161b_DATA, 64, USB161b_TRBCTL_DATA);
  }
}

STATIC VOID
Usb161bEvent (
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
      Dcfg = Usb161bRd (USB161b_DCFG) & ~(0x7FU << 3);
      Usb161bWr (USB161b_DCFG, Dcfg);
      Usb161bPrint (L"  [USB161b] bus reset");
    } else if (Type == 2) {          // connect done: EP0 max packet 64
      Speed = Usb161bRd (USB161b_DSTS) & 7;
      Usb161bEpCmd (0, USB161b_DEPCMD_SETEPCONFIG, (0U << 1) | (64U << 3) | (2U << 30),
                   (1U << 8) | (1U << 10) | (0U << 25), 0);
      Usb161bEpCmd (1, USB161b_DEPCMD_SETEPCONFIG, (0U << 1) | (64U << 3) | (2U << 30),
                   (1U << 8) | (1U << 10) | (1U << 25), 0);
      Usb161bPrint (L"  [USB161b] connect done speed=%u", Speed);
    } else if (Type == 0) {          // disconnect
      Usb161bPrint (L"  [USB161b] disconnect");
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
    switch (mUsb161bState) {
    case USB161b_ST_SETUP:
      Usb161bInval ((UINTN)(mUsb161bDma + USB161b_SETUP), 8);
      Usb161bSetup ();
      break;
    case USB161b_ST_DATA:
      mUsb161bState = USB161b_ST_WAIT_STATUS3;
      break;
    case USB161b_ST_STATUS:
      Usb161bArmSetup ();
      break;
    default:
      break;
    }
    return;
  }

  if ((EvType == 3) && (Status == 2)) {  // XferNotReady, control status phase
    if ((mUsb161bState == USB161b_ST_WAIT_STATUS2) || (mUsb161bState == USB161b_ST_WAIT_STATUS3)) {
      UINT32 Ctl = (mUsb161bState == USB161b_ST_WAIT_STATUS3) ? USB161b_TRBCTL_STATUS3 : USB161b_TRBCTL_STATUS2;
      mUsb161bState = USB161b_ST_STATUS;
      Usb161bStart (Ep, USB161b_DATA, 0, Ctl);
    }
  }
}

STATIC VOID
Usb161bPoll (
  VOID
  )
{
  UINT32  Count;
  UINT32  Done;
  UINT32  Ev;

  if (!mUsb161bReady) {
    return;
  }
  Count = Usb161bRd (USB161b_GEVNTCOUNT) & 0xFFFF;
  if (Count == 0) {
    return;
  }
  Usb161bInval ((UINTN)(mUsb161bDma + USB161b_EVT), USB161b_EVT_SIZE);
  for (Done = 0; Done + 4 <= Count; Done += 4) {
    Ev = *(volatile UINT32 *)(UINTN)(mUsb161bDma + USB161b_EVT + mUsb161bEvtPos);
    mUsb161bEvtPos = (mUsb161bEvtPos + 4) % USB161b_EVT_SIZE;
    mUsb161bEvents++;
    if (mUsb161bRawLogs < 8) {
      mUsb161bRawLogs++;
      if ((Ev & 1) != 0) {
        Usb161bPrint (L"  [USB161b] evt raw=%08x type=%u ep=dev", Ev, (Ev >> 8) & 0xF);
      } else {
        Usb161bPrint (L"  [USB161b] evt raw=%08x type=%u ep=%u", Ev, (Ev >> 6) & 0xF, (Ev >> 1) & 0x1F);
      }
    } else if (mUsb161bEvents <= 60) {
      Usb161bPrint (L"  [USB161b] evt=%08x", Ev);
    }
    Usb161bEvent (Ev);
  }
  Usb161bWr (USB161b_GEVNTCOUNT, Count);   // write back to clear
}

STATIC VOID
Usb161bStat (
  VOID
  )
{
  UINT32  Dsts;
  UINT32  Count;
  UINT32  Dcfg;

  Dsts  = Usb161bRd (USB161b_DSTS);
  Count = Usb161bRd (USB161b_GEVNTCOUNT) & 0xFFFF;
  Dcfg  = Usb161bRd (USB161b_DCFG);
  Usb161bPrint (L"  [USB161b] poll: DCTL=%08x DSTS=%08x PHYCFG=%08x SIZ=%08x",
               Usb161bRd (USB161b_DCTL), Dsts, Usb161bRd (USB161b_GUSB2PHYCFG),
               Usb161bRd (USB161b_GEVNTSIZ));
  Usb161bPrint (L"  [USB161b] poll2: hlt22=%d spd=%u devspd=%u cnt=%08x",
               (Dsts >> 22) & 1, Dsts & 7, Dcfg & 7, Count);
  if ((Dsts != mUsb161bLastDsts) || (Count != mUsb161bLastCount)) {
    mUsb161bLastDsts  = Dsts;
    mUsb161bLastCount = Count;
    Usb161bPrint (L"  [USB161b] regs: DCFG=%08x devspd=%u devaddr=%u DALEPENA=%08x",
                 Dcfg, Dcfg & 7, (Dcfg >> 3) & 0x7F, Usb161bRd (USB161b_DALEPENA));
    Usb161bPrint (L"  [USB161b] regs2: DEVTEN=%08x DCTL=%08x PHYCFG=%08x GEVNTSIZ=%08x",
                 Usb161bRd (USB161b_DEVTEN), Usb161bRd (USB161b_DCTL),
                 Usb161bRd (USB161b_GUSB2PHYCFG), Usb161bRd (USB161b_GEVNTSIZ));
    Usb161bPrint (L"  [USB161b] regs3: DEPCMD0=%08x PAR0(0)=%08x evtaddr=%08x%08x",
                 Usb161bRd (USB161b_DEPCMD (0)), Usb161bRd (USB161b_DEPCMDPAR0 (0)),
                 Usb161bRd (USB161b_GEVNTADRHI), Usb161bRd (USB161b_GEVNTADRLO));
  }
}

STATIC VOID
Usb161bInit (
  VOID
  )
{
  EFI_PHYSICAL_ADDRESS  DmaPa;
  EFI_STATUS            Status;
  UINTN                 I;
  UINTN                 Ticks;
  UINT32                Gsnpsid;
  UINT32                Dsts;

  Status = gBS->AllocatePages (AllocateAnyPages, EfiBootServicesData, USB161b_DMA_SIZE / 0x1000, &DmaPa);
  if (EFI_ERROR (Status)) {
    Say (L"  [USB161b] FATAL: no DMA pages");
    return;
  }
  mUsb161bDma = (UINT8 *)(UINTN)DmaPa;
  ZeroMem (mUsb161bDma, USB161b_DMA_SIZE);
  Usb161bPrint (L"  [USB161b] dma=%08x%08x (16 KiB)", (UINT32)(((UINT64)(UINTN)mUsb161bDma) >> 32),
               (UINT32)(UINTN)mUsb161bDma);

  //
  // 1) MINIMAL-WRITE variant: only clear PHY suspend (SUSPHY bit6) and
  //    suspend-on-sleep (ENBLSLPM bit8); PHYSOFTRST is left as-is.
  //
  Usb161bWr (USB161b_GUSB2PHYCFG, Usb161bRd (USB161b_GUSB2PHYCFG) & ~USB161b_PHYCFG_CLEAR);
  gBS->Stall (20000);
  Usb161bPrint (L"  [USB161b] phycfg=%08x gctl=%08x dctl=%08x", Usb161bRd (USB161b_GUSB2PHYCFG),
                Usb161bRd (USB161b_GCTL), Usb161bRd (USB161b_DCTL));

  //
  // 2) Event buffer, interrupt masked (bit31), polled from the resident loop.
  //
  Usb161bWr (USB161b_GEVNTADRLO, (UINT32)(UINTN)mUsb161bDma);
  Usb161bWr (USB161b_GEVNTADRHI, (UINT32)(((UINT64)(UINTN)mUsb161bDma) >> 32));
  Usb161bWr (USB161b_GEVNTSIZ,   USB161b_EVT_SIZE);
  Usb161bWr (USB161b_GEVNTCOUNT, Usb161bRd (USB161b_GEVNTCOUNT) & 0xFFFF);
  mUsb161bEvtPos = 0;
  Usb161bPrint (L"  [USB161b] evt: addr=%08x%08x siz=%08x cnt=%08x",
               Usb161bRd (USB161b_GEVNTADRHI), Usb161bRd (USB161b_GEVNTADRLO),
               Usb161bRd (USB161b_GEVNTSIZ), Usb161bRd (USB161b_GEVNTCOUNT));

  //
  // 3) High speed, address 0; device events: disconnect / USB reset / connect done.
  //
  Usb161bWr (USB161b_DCFG, Usb161bRd (USB161b_DCFG) & ~(7U | (0x7FU << 3)));
  Usb161bWr (USB161b_DEVTEN, 0x7);

  //
  // 4) EP0 OUT (dep 0) and EP0 IN (dep 1), control type, mps 512 for now.
  //
  Usb161bEpCmd (0, USB161b_DEPCMD_DEPSTARTCFG, 0, 0, 0);
  Usb161bEpCmd (0, USB161b_DEPCMD_SETEPCONFIG, (0U << 1) | (512U << 3),
               (1U << 8) | (1U << 10) | (0U << 25), 0);
  Usb161bEpCmd (0, USB161b_DEPCMD_SETTRANSFRESOURCE, 1, 0, 0);
  Usb161bEpCmd (1, USB161b_DEPCMD_SETEPCONFIG, (0U << 1) | (512U << 3),
               (1U << 8) | (1U << 10) | (1U << 25), 0);
  Usb161bEpCmd (1, USB161b_DEPCMD_SETTRANSFRESOURCE, 1, 0, 0);
  Usb161bWr (USB161b_DALEPENA, 0x3);

  //
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
  mUsb161bState = USB161b_ST_SETUP;
  Usb161bArmSetup ();
  Dsts    = Usb161bRd (USB161b_DSTS);
  Gsnpsid = Usb161bRd (USB161b_GSNPSID);
  mUsb161bReady = TRUE;
  Usb161bPrint (L"  [USB161b] gadget up: GSNPSID=%08x GCTL=%08x DCFG=%08x DEVTEN=%08x",
               Gsnpsid, Usb161bRd (USB161b_GCTL), Usb161bRd (USB161b_DCFG),
               Usb161bRd (USB161b_DEVTEN));
  Usb161bPrint (L"  [USB161b] up2: DALEPENA=%08x DSTS=%08x hlt22=%d spd=%u",
               Usb161bRd (USB161b_DALEPENA), Dsts, (Dsts >> 22) & 1, Dsts & 7);
  Usb161bPrint (L"  [USB161b] bringup done: hlt22=%d phycfg_bit6=%d devspd=%u",
               (Dsts >> 22) & 1, (Usb161bRd (USB161b_GUSB2PHYCFG) >> 6) & 1, Dsts & 7);
}

'''

c = s.find("STATIC\nVOID\nForceLoadSimpleFb (\n")
if c < 0:
    print("patch_usb161b: FATAL ForceLoadSimpleFb not found")
    sys.exit(1)
d = s.find("STATIC\nVOID\nProbeGop (\n", c)
if d < 0:
    print("patch_usb161b: FATAL ProbeGop not found")
    sys.exit(1)
s = s[:c] + NEW_FB + s[d:]

a = s.find("STATIC UINT32\nUsb150Rd (\n")
if a < 0:
    print("patch_usb161b: FATAL Usb150Rd block not found")
    sys.exit(1)
b = s.find("EFI_STATUS\nEFIAPI\nVermeerMenuDxeEntry", a)
if b < 0:
    print("patch_usb161b: FATAL entry not found")
    sys.exit(1)
s = s[:a] + NEW_GADGET + s[b:]

a = s.find('  Say (L"  [MENU150] console stays on, USB150 diag then photo halt");')
if a < 0:
    print("patch_usb161b: FATAL MENU150 entry tail not found")
    sys.exit(1)
b = s.find("  CpuDeadLoop ();", a)
if b < 0:
    print("patch_usb161b: FATAL CpuDeadLoop not found")
    sys.exit(1)
b += len("  CpuDeadLoop ();")

NEW_TAIL = '''  Say (L"  [MENU161b] minimal EP0 gadget: polling event buffer, staying enumerated");
  {
    STATIC UINTN  mGuiDisabled161b = 0;
    STATIC UINTN  mTicks161b       = 0;
    EFI_INPUT_KEY Key;
    BOOLEAN       Got;

    Usb161bInit ();
    for (;;) {
      Usb161bPoll ();
      if ((mTicks161b % 1000) == 0) {
        Usb161bStat ();
      }
      if ((mTicks161b % 5000) == 0) {
        Say (L"  [USB161b] alive");
      }
      mTicks161b++;
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
    Say (L"  [MENU161b] key pressed, leaving resident loop");
    if (mGuiDisabled161b == 0) {
      RunMenu ();
    }
  }
  Say (L"  [MENU161b] done, returning to BDS");'''

s = s[:a] + NEW_TAIL + s[b:]

# ---- sanity -----------------------------------------------------------------
for bad in ("Usb150Wr (", "Usb150Rd (", "Usb150Dump (", "Usb150LateDiag", "CpuDeadLoop ()",
            "0x0010F004", "0x0010F000", "0x0A6F8800"):
    if bad in s:
        print("patch_usb161b: FATAL still contains %r" % bad)
        sys.exit(1)
for need in ("[MENU161b]", "[USB161b]", "Usb161bInit", "Usb161bPoll", "Usb161bStat", "RunMenu ()",
             "USB161b_DEPCMD_STARTTRANSFER", "mUsb161bCfgDesc", "K70 UEFI DEBUG"):
    if need not in s:
        print("patch_usb161b: FATAL missing %r" % need)
        sys.exit(1)

P.write_text(s, encoding="utf-8")
print("patch_usb161b: Menu -> minimal DWC3 EP0 gadget (polled events, 1 cfg, no CDC/MSD)")
print("PATCH_USB161b OK")
