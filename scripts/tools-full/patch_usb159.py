#!/usr/bin/env python3
"""patch_usb159.py -- keys159: Menu hosts a MINIMAL DWC3 device-mode EP0 gadget.

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

Idempotent via the "[MENU159]" marker.
"""
import pathlib
import sys

P = pathlib.Path("/root/k70/uefi/Platforms/Xiaomi/vermeerPkg/Drivers/VermeerMenuDxe/VermeerMenuDxe.c")
s = P.read_text(encoding="utf-8")

if "[MENU159]" in s:
    print("patch_usb159: already patched")
    sys.exit(0)

if "[MENU150]" not in s or "Usb150LateDiag" not in s:
    print("patch_usb159: FATAL pristine keys150 menu block not found")
    sys.exit(1)

NEW_FB = r'''STATIC
VOID
ForceLoadSimpleFb (
  VOID
  )
{
  //
  // keys159: SimpleFb LoadImage/StartImage intentionally disabled (text UI only).
  //
  if (mFbLoadTried) {
    return;
  }
  mFbLoadTried = TRUE;
  Say (L"  [UI159] SimpleFb load disabled (keys159)");
}

'''

NEW_GADGET = r'''//
// ============================ keys159: minimal EP0 ==========================
//
// DWC3 device-mode registers (same map used by keys158 / the reference impl).
//
#define USB159_BASE          0x0A600000
#define USB159_GSNPSID       0x0C120
#define USB159_GEVNTADRLO    0x0C400
#define USB159_GEVNTADRHI    0x0C404
#define USB159_GEVNTSIZ      0x0C408
#define USB159_GEVNTCOUNT    0x0C40C
#define USB159_DCFG          0x0C700
#define USB159_DCTL          0x0C704
#define USB159_DEVTEN        0x0C708
#define USB159_DSTS          0x0C70C
#define USB159_DALEPENA      0x0C720
#define USB159_DEPCMDPAR2(n) (0x0C800 + 0x10 * (n))
#define USB159_DEPCMDPAR1(n) (0x0C804 + 0x10 * (n))
#define USB159_DEPCMDPAR0(n) (0x0C808 + 0x10 * (n))
#define USB159_DEPCMD(n)     (0x0C80C + 0x10 * (n))

#define USB159_DCTL_RUN_STOP   (1U << 31)
#define USB159_DCTL_CSFTRST    (1U << 30)
#define USB159_DSTS_DEVCTRLHLT (1U << 22)

#define USB159_DEPCMD_SETEPCONFIG       1
#define USB159_DEPCMD_SETTRANSFRESOURCE 2
#define USB159_DEPCMD_SETSTALL          4
#define USB159_DEPCMD_STARTTRANSFER     6
#define USB159_DEPCMD_DEPSTARTCFG       9
#define USB159_DEPCMD_CMDACT            (1U << 10)

#define USB159_TRB_HWO      (1U << 0)
#define USB159_TRB_LST      (1U << 1)
#define USB159_TRB_ISP_IMI  (1U << 10)
#define USB159_TRB_IOC      (1U << 11)
#define USB159_TRBCTL_SETUP   (2U << 4)
#define USB159_TRBCTL_STATUS2 (3U << 4)
#define USB159_TRBCTL_STATUS3 (4U << 4)
#define USB159_TRBCTL_DATA    (5U << 4)

// DMA area layout inside one 16 KiB allocation.
#define USB159_EVT        0x0000
#define USB159_EVT_SIZE   0x1000
#define USB159_TRB_OUT    0x1000
#define USB159_TRB_IN     0x1010
#define USB159_SETUP      0x1040
#define USB159_DATA       0x1100
#define USB159_DMA_SIZE   0x4000

// Control-transfer states.
#define USB159_ST_SETUP        0
#define USB159_ST_DATA         1
#define USB159_ST_WAIT_STATUS2 2
#define USB159_ST_WAIT_STATUS3 3
#define USB159_ST_STATUS       4

#define USB159_MAX_STR 126

STATIC UINT8   *mUsb159Dma;
STATIC UINTN    mUsb159EvtPos;
STATIC UINT32   mUsb159State;
STATIC BOOLEAN  mUsb159DataIn;
STATIC UINT32   mUsb159Events;
STATIC BOOLEAN  mUsb159Ready;
STATIC UINT32   mUsb159SetupCount;
STATIC UINT32   mUsb159DescCount;

STATIC UINT32
Usb159Rd (
  IN UINTN  Off
  )
{
  return *(volatile UINT32 *)(UINTN)(USB159_BASE + Off);
}

STATIC VOID
Usb159Wr (
  IN UINTN   Off,
  IN UINT32  Value
  )
{
  *(volatile UINT32 *)(UINTN)(USB159_BASE + Off) = Value;
  __asm__ __volatile__ ("dsb sy" ::: "memory");
}

STATIC VOID
Usb159Clean (
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
Usb159Inval (
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
Usb159Print (
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
Usb159EpCmd (
  IN UINT32  Ep,
  IN UINT32  Cmd,
  IN UINT32  Param0,
  IN UINT32  Param1,
  IN UINT32  Param2
  )
{
  UINTN   I;
  UINT32  Value;

  Usb159Wr (USB159_DEPCMDPAR2 (Ep), Param2);
  Usb159Wr (USB159_DEPCMDPAR1 (Ep), Param1);
  Usb159Wr (USB159_DEPCMDPAR0 (Ep), Param0);
  Usb159Wr (USB159_DEPCMD (Ep), Cmd | USB159_DEPCMD_CMDACT);

  for (I = 0; I < 200; I++) {
    Value = Usb159Rd (USB159_DEPCMD (Ep));
    if ((Value & USB159_DEPCMD_CMDACT) == 0) {
      if (((Value >> 12) & 0xF) != 0) {
        Usb159Print (L"  [USB159] ep%u cmd %u status %u", Ep, Cmd & 0xF, (Value >> 12) & 0xF);
        return EFI_DEVICE_ERROR;
      }
      return EFI_SUCCESS;
    }
    gBS->Stall (10);
  }
  Usb159Print (L"  [USB159] ep%u cmd %u timeout", Ep, Cmd & 0xF);
  return EFI_TIMEOUT;
}

STATIC VOID
Usb159Start (
  IN UINT32  Ep,
  IN UINTN   BufOff,
  IN UINT32  Length,
  IN UINT32  Ctl
  )
{
  volatile UINT32  *Trb;
  UINT64           BufPa;
  UINT64           TrbPa;

  Trb   = (volatile UINT32 *)(UINTN)(mUsb159Dma + (Ep ? USB159_TRB_IN : USB159_TRB_OUT));
  BufPa = (UINT64)(UINTN)(mUsb159Dma + BufOff);
  Trb[0] = (UINT32)BufPa;
  Trb[1] = (UINT32)(BufPa >> 32);
  Trb[2] = Length;
  Trb[3] = Ctl | USB159_TRB_HWO | USB159_TRB_LST | USB159_TRB_ISP_IMI | USB159_TRB_IOC;
  Usb159Clean ((UINTN)Trb, 16);
  if (Length != 0) {
    Usb159Clean ((UINTN)(mUsb159Dma + BufOff), Length);
  }
  TrbPa = (UINT64)(UINTN)Trb;
  Usb159EpCmd (Ep, USB159_DEPCMD_STARTTRANSFER, 0, (UINT32)TrbPa, (UINT32)(TrbPa >> 32));
}

STATIC VOID
Usb159ArmSetup (
  VOID
  )
{
  mUsb159State = USB159_ST_SETUP;
  Usb159Start (0, USB159_SETUP, 8, USB159_TRBCTL_SETUP);
}

STATIC VOID
Usb159Stall (
  VOID
  )
{
  Usb159EpCmd (0, USB159_DEPCMD_SETSTALL, 0, 0, 0);
  Usb159ArmSetup ();
}

STATIC CONST UINT8  mUsb159DevDesc[18] = {
  18, 1, 0x00, 0x02, 0x00, 0x00, 0x00, 64,
  0x09, 0x12, 0x01, 0xC1, 0x00, 0x01, 1, 2, 3, 1
};

STATIC CONST UINT8  mUsb159CfgDesc[18] = {
  9, 2, 18, 0, 1, 1, 0, 0x80, 250,
  9, 4, 0, 0, 0, 0xFF, 0x00, 0x00, 0
};

STATIC CONST CHAR8  *mUsb159Strings[3] = {
  NULL, "Vermeer", "K70 UEFI DEBUG"
};

STATIC UINT32
Usb159String (
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
  Str = mUsb159Strings[Index];
  N = 2;
  while ((*Str != 0) && (N < USB159_MAX_STR)) {
    Out[N++] = (UINT8)*Str++;
    Out[N++] = 0;
  }
  Out[0] = (UINT8)N;
  Out[1] = 3;
  return N;
}

STATIC VOID
Usb159Setup (
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

  St     = (CONST UINT8 *)(UINTN)(mUsb159Dma + USB159_SETUP);
  Data   = (UINT8 *)(UINTN)(mUsb159Dma + USB159_DATA);
  Type   = St[0];
  Req    = St[1];
  Value  = (UINT16)(St[2] | (St[3] << 8));
  Length = (UINT16)(St[6] | (St[7] << 8));
  N      = 0;
  Ok     = TRUE;

  mUsb159SetupCount++;
  if (mUsb159SetupCount <= 40) {
    Usb159Print (L"  [USB159] setup bm=%02x b=%02x wv=%04x wi=%04x wl=%04x",
                 Type, Req, Value,
                 (UINT16)(St[4] | (St[5] << 8)), Length);
  }
  mUsb159DataIn = ((Type & 0x80) != 0);

  if ((Type & 0x60) != 0) {
    Ok = FALSE;                       // only standard requests
  } else if (Req == 6) {             // GET_DESCRIPTOR
    switch ((UINT8)(Value >> 8)) {
    case 1:
      CopyMem (Data, mUsb159DevDesc, sizeof (mUsb159DevDesc));
      N = sizeof (mUsb159DevDesc);
      break;
    case 2:
      CopyMem (Data, mUsb159CfgDesc, sizeof (mUsb159CfgDesc));
      N = sizeof (mUsb159CfgDesc);
      break;
    case 3:
      N = Usb159String (Value & 0xFF, Data);
      Ok = (N != 0);
      break;
    default:
      Ok = FALSE;
      break;
    }
    if (Ok && (mUsb159DescCount++ < 40)) {
      Usb159Print (L"  [USB159] desc type=%02x len=%u", (UINT8)(Value >> 8), N);
    }
  } else if (Req == 5) {             // SET_ADDRESS
    Dcfg = Usb159Rd (USB159_DCFG) & ~(0x7FU << 3);
    Usb159Wr (USB159_DCFG, Dcfg | ((UINT32)(Value & 0x7F) << 3));
    Usb159Print (L"  [USB159] address=%u", Value & 0x7F);
  } else if (Req == 9) {             // SET_CONFIGURATION
    Usb159Print (L"  [USB159] configured=%u", Value);
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
    Usb159Print (L"  [USB159] stall b=%02x", Req);
    Usb159Stall ();
    return;
  }
  if (Length == 0) {
    mUsb159State = USB159_ST_WAIT_STATUS2;
    return;
  }
  mUsb159State = USB159_ST_DATA;
  if (mUsb159DataIn) {
    if (N > Length) {
      N = Length;
    }
    Usb159Start (1, USB159_DATA, N, USB159_TRBCTL_DATA);
  } else {
    Usb159Start (0, USB159_DATA, 64, USB159_TRBCTL_DATA);
  }
}

STATIC VOID
Usb159Event (
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
      Dcfg = Usb159Rd (USB159_DCFG) & ~(0x7FU << 3);
      Usb159Wr (USB159_DCFG, Dcfg);
      Usb159Print (L"  [USB159] bus reset");
    } else if (Type == 2) {          // connect done: EP0 max packet 64
      Speed = Usb159Rd (USB159_DSTS) & 7;
      Usb159EpCmd (0, USB159_DEPCMD_SETEPCONFIG, (0U << 1) | (64U << 3) | (2U << 30),
                   (1U << 8) | (1U << 10) | (0U << 25), 0);
      Usb159EpCmd (1, USB159_DEPCMD_SETEPCONFIG, (0U << 1) | (64U << 3) | (2U << 30),
                   (1U << 8) | (1U << 10) | (1U << 25), 0);
      Usb159Print (L"  [USB159] connect done speed=%u", Speed);
    } else if (Type == 0) {          // disconnect
      Usb159Print (L"  [USB159] disconnect");
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
    switch (mUsb159State) {
    case USB159_ST_SETUP:
      Usb159Inval ((UINTN)(mUsb159Dma + USB159_SETUP), 8);
      Usb159Setup ();
      break;
    case USB159_ST_DATA:
      mUsb159State = USB159_ST_WAIT_STATUS3;
      break;
    case USB159_ST_STATUS:
      Usb159ArmSetup ();
      break;
    default:
      break;
    }
    return;
  }

  if ((EvType == 3) && (Status == 2)) {  // XferNotReady, control status phase
    if ((mUsb159State == USB159_ST_WAIT_STATUS2) || (mUsb159State == USB159_ST_WAIT_STATUS3)) {
      UINT32 Ctl = (mUsb159State == USB159_ST_WAIT_STATUS3) ? USB159_TRBCTL_STATUS3 : USB159_TRBCTL_STATUS2;
      mUsb159State = USB159_ST_STATUS;
      Usb159Start (Ep, USB159_DATA, 0, Ctl);
    }
  }
}

STATIC VOID
Usb159Poll (
  VOID
  )
{
  UINT32  Count;
  UINT32  Done;
  UINT32  Ev;

  if (!mUsb159Ready) {
    return;
  }
  Count = Usb159Rd (USB159_GEVNTCOUNT) & 0xFFFF;
  if (Count == 0) {
    return;
  }
  Usb159Inval ((UINTN)(mUsb159Dma + USB159_EVT), USB159_EVT_SIZE);
  for (Done = 0; Done + 4 <= Count; Done += 4) {
    Ev = *(volatile UINT32 *)(UINTN)(mUsb159Dma + USB159_EVT + mUsb159EvtPos);
    mUsb159EvtPos = (mUsb159EvtPos + 4) % USB159_EVT_SIZE;
    mUsb159Events++;
    if (mUsb159Events <= 60) {
      Usb159Print (L"  [USB159] evt=%08x", Ev);
    }
    Usb159Event (Ev);
  }
  Usb159Wr (USB159_GEVNTCOUNT, Count);   // write back to clear
}

STATIC VOID
Usb159Init (
  VOID
  )
{
  EFI_PHYSICAL_ADDRESS  DmaPa;
  EFI_STATUS            Status;
  UINTN                 I;
  UINT32                Gsnpsid;
  UINT32                Dsts;

  Status = gBS->AllocatePages (AllocateAnyPages, EfiBootServicesData, USB159_DMA_SIZE / 0x1000, &DmaPa);
  if (EFI_ERROR (Status)) {
    Say (L"  [USB159] FATAL: no DMA pages");
    return;
  }
  mUsb159Dma = (UINT8 *)(UINTN)DmaPa;
  ZeroMem (mUsb159Dma, USB159_DMA_SIZE);
  Usb159Print (L"  [USB159] dma=%08x%08x (16 KiB)", (UINT32)(((UINT64)(UINTN)mUsb159Dma) >> 32),
               (UINT32)(UINTN)mUsb159Dma);

  //
  // 1) Device soft reset (PHY / clocks stay as XBL-BL left them).
  //
  Usb159Wr (USB159_DCTL, USB159_DCTL_CSFTRST);
  for (I = 0; (I < 500) && ((Usb159Rd (USB159_DCTL) & USB159_DCTL_CSFTRST) != 0); I++) {
    gBS->Stall (1000);
  }
  Usb159Print (L"  [USB159] soft reset done after %u ms GCTL=%08x",
               (UINT32)I, Usb159Rd (0x0C110));
  if ((Usb159Rd (USB159_DCTL) & USB159_DCTL_CSFTRST) != 0) {
    Say (L"  [USB159] FATAL: soft reset stuck");
    return;
  }

  //
  // 2) Event buffer, interrupt masked (bit31), polled from the resident loop.
  //
  Usb159Wr (USB159_GEVNTADRLO, (UINT32)(UINTN)mUsb159Dma);
  Usb159Wr (USB159_GEVNTADRHI, (UINT32)(((UINT64)(UINTN)mUsb159Dma) >> 32));
  Usb159Wr (USB159_GEVNTSIZ,   (1U << 31) | USB159_EVT_SIZE);
  Usb159Wr (USB159_GEVNTCOUNT, Usb159Rd (USB159_GEVNTCOUNT) & 0xFFFF);
  mUsb159EvtPos = 0;

  //
  // 3) High speed, address 0; device events: disconnect / USB reset / connect done.
  //
  Usb159Wr (USB159_DCFG, Usb159Rd (USB159_DCFG) & ~(7U | (0x7FU << 3)));
  Usb159Wr (USB159_DEVTEN, 0x7);

  //
  // 4) EP0 OUT (dep 0) and EP0 IN (dep 1), control type, mps 512 for now.
  //
  Usb159EpCmd (0, USB159_DEPCMD_DEPSTARTCFG, 0, 0, 0);
  Usb159EpCmd (0, USB159_DEPCMD_SETEPCONFIG, (0U << 1) | (512U << 3),
               (1U << 8) | (1U << 10) | (0U << 25), 0);
  Usb159EpCmd (0, USB159_DEPCMD_SETTRANSFRESOURCE, 1, 0, 0);
  Usb159EpCmd (1, USB159_DEPCMD_SETEPCONFIG, (0U << 1) | (512U << 3),
               (1U << 8) | (1U << 10) | (1U << 25), 0);
  Usb159EpCmd (1, USB159_DEPCMD_SETTRANSFRESOURCE, 1, 0, 0);
  Usb159Wr (USB159_DALEPENA, 0x3);

  mUsb159State = USB159_ST_SETUP;
  Usb159ArmSetup ();

  //
  // 5) Run.
  //
  Usb159Wr (USB159_DCTL, Usb159Rd (USB159_DCTL) | USB159_DCTL_RUN_STOP);
  for (I = 0; (I < 500) && ((Usb159Rd (USB159_DSTS) & USB159_DSTS_DEVCTRLHLT) != 0); I++) {
    gBS->Stall (1000);
  }
  Dsts    = Usb159Rd (USB159_DSTS);
  Gsnpsid = Usb159Rd (USB159_GSNPSID);
  mUsb159Ready = TRUE;
  Usb159Print (L"  [USB159] gadget up: GSNPSID=%08x DSTS=%08x hlt22=%d spd=%u",
               Gsnpsid, Dsts, (Dsts >> 22) & 1, Dsts & 7);
}

'''

c = s.find("STATIC\nVOID\nForceLoadSimpleFb (\n")
if c < 0:
    print("patch_usb159: FATAL ForceLoadSimpleFb not found")
    sys.exit(1)
d = s.find("STATIC\nVOID\nProbeGop (\n", c)
if d < 0:
    print("patch_usb159: FATAL ProbeGop not found")
    sys.exit(1)
s = s[:c] + NEW_FB + s[d:]

a = s.find("STATIC UINT32\nUsb150Rd (\n")
if a < 0:
    print("patch_usb159: FATAL Usb150Rd block not found")
    sys.exit(1)
b = s.find("EFI_STATUS\nEFIAPI\nVermeerMenuDxeEntry", a)
if b < 0:
    print("patch_usb159: FATAL entry not found")
    sys.exit(1)
s = s[:a] + NEW_GADGET + s[b:]

a = s.find('  Say (L"  [MENU150] console stays on, USB150 diag then photo halt");')
if a < 0:
    print("patch_usb159: FATAL MENU150 entry tail not found")
    sys.exit(1)
b = s.find("  CpuDeadLoop ();", a)
if b < 0:
    print("patch_usb159: FATAL CpuDeadLoop not found")
    sys.exit(1)
b += len("  CpuDeadLoop ();")

NEW_TAIL = '''  Say (L"  [MENU159] minimal EP0 gadget: polling event buffer, staying enumerated");
  {
    STATIC UINTN  mGuiDisabled159 = 0;
    STATIC UINTN  mTicks159       = 0;
    EFI_INPUT_KEY Key;
    BOOLEAN       Got;

    Usb159Init ();
    for (;;) {
      Usb159Poll ();
      if ((mTicks159 % 5000) == 0) {
        Say (L"  [USB159] alive");
      }
      mTicks159++;
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
    Say (L"  [MENU159] key pressed, leaving resident loop");
    if (mGuiDisabled159 == 0) {
      RunMenu ();
    }
  }
  Say (L"  [MENU159] done, returning to BDS");'''

s = s[:a] + NEW_TAIL + s[b:]

# ---- sanity -----------------------------------------------------------------
for bad in ("Usb150Wr (", "Usb150Rd (", "Usb150Dump (", "Usb150LateDiag", "CpuDeadLoop ()",
            "0x0010F004", "0x0010F000", "0x0A6F8800"):
    if bad in s:
        print("patch_usb159: FATAL still contains %r" % bad)
        sys.exit(1)
for need in ("[MENU159]", "[USB159]", "Usb159Init", "Usb159Poll", "RunMenu ()",
             "USB159_DEPCMD_STARTTRANSFER", "mUsb159CfgDesc", "K70 UEFI DEBUG"):
    if need not in s:
        print("patch_usb159: FATAL missing %r" % need)
        sys.exit(1)

P.write_text(s, encoding="utf-8")
print("patch_usb159: Menu -> minimal DWC3 EP0 gadget (polled events, 1 cfg, no CDC/MSD)")
print("PATCH_USB159 OK")
