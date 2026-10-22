/** @file
  Key probe for the Redmi K70 (vermeer) UEFI port.

  Why this exists
  ---------------
  The port can boot, draw text and keep an event loop alive, but there is no input device:
  the firmware contains no button driver, so the boot manager menu and the shell are
  unreachable.  The device tree says the only declared key is

      /soc/gpio_keys/vol_up  linux,code=115 (KEY_VOLUMEUP)  gpios=<&pm8550_gpios 6 GPIO_ACTIVE_LOW>

  i.e. volume-up is PM8550 GPIO 6, NOT a TLMM pad, so a "read the SoC GPIO" driver cannot see
  it.  The stock firmware reads it through the vendor SPMI/PMIC stack, which is why this probe
  is paired with a selective vendor gate (SPMIDxe + PmicDxe + ButtonsDxe only).

  What it does
  ------------
  1. Prints which vendor protocols actually got installed.  DepEx-gated drivers that cannot
     dispatch are skipped silently by the DXE core, so "nothing happened" is otherwise
     indistinguishable from "the driver is broken".
  2. Then waits for keystrokes forever and prints every one it sees (scan code + Unicode
     character + count), polling BOTH the console's ConIn and every SimpleTextIn instance in
     the system.  Whatever the vendor button driver publishes, this will show it.

  It never returns, so the screen stays readable instead of the machine trying to boot, failing
  and resetting (ResetSystem -> PSCI SYSTEM_OFF looks like a crash but is a clean shutdown).

  Gated behind VERMEER_KEYPROBE in vermeer.dsc / vermeer.fdf, default 0.
**/

#include <Uefi.h>
#include <Library/DxeServicesLib.h>
#include <Library/UefiBootServicesTableLib.h>
#include <Library/UefiLib.h>
#include <Library/DebugLib.h>
#include <Library/BaseLib.h>
#include <Library/BaseMemoryLib.h>
#include <Library/PrintLib.h>
#include <Protocol/SimpleTextIn.h>
#include <Library/UefiRuntimeServicesTableLib.h>
#include <Library/MemoryAllocationLib.h>
#include <Library/CacheMaintenanceLib.h>
#include <Library/DxeServicesTableLib.h>
#define UFS41_DUMPONLY_OFF 1

#define ALIVE_INTERVAL_US       (1 * 1000 * 1000)   // 1 s: keys45 runs a menu countdown
#define ACTION_DELAY_SECONDS    3
#define MAX_TEXTIN_HANDLES      16
#define KEYPROBE_ARRAY_SIZE(a)  (sizeof (a) / sizeof ((a)[0]))

typedef struct {
  CONST CHAR8  *Name;
  EFI_GUID     Guid;
} GUID_PROBE;

//
// Protocol GUIDs taken from the vendor DEPEX files (decoded byte-for-byte from
// QcomPkg/Drivers/*/**.depex in Device-Binaries/nuwa, which we know is byte-identical to what
// this phone shipped).  Names are guesses based on which driver pushed them.
//
STATIC GUID_PROBE mProbes[] = {
  { "SPMI (SPMIDxe)",      { 0xae37b942, 0x457f, 0x4c91, { 0xa1, 0x96, 0xd9, 0x66, 0x9f, 0xd3, 0x47, 0xa3 } } },
  { "PMIC 2nd (PmicDxe)",  { 0xfa5f306b, 0xf47d, 0x4ac4, { 0xa4, 0x7d, 0x88, 0x2f, 0x82, 0x04, 0xec, 0x30 } } },
  { "Clock (ClockDxe)",    { 0xb0760469, 0x970c, 0x487a, { 0xa4, 0xb5, 0x28, 0xdb, 0x7b, 0x45, 0xce, 0xf1 } } },
  { "Buttons dep #1",      { 0x157a5c45, 0x21b2, 0x43c5, { 0xba, 0x7c, 0x82, 0x2f, 0xee, 0x5f, 0xe5, 0x99 } } },
  { "Buttons dep #2",      { 0x4bc5c6d7, 0x4ca4, 0x8835, { 0xd1, 0xbc, 0xd2, 0x9c, 0xc2, 0x02, 0x5d, 0x4a } } },
  { "Buttons dep #3",      { 0x9ba45b66, 0xefa4, 0x441c, { 0xa3, 0xe4, 0xed, 0x22, 0x24, 0x78, 0x6b, 0xe2 } } },
  { "Buttons dep #4",      { 0xad9aec18, 0x7bf0, 0x4809, { 0x9e, 0x96, 0x30, 0x12, 0x30, 0x9f, 0x3d, 0xf7 } } },
  { "SMEM (SmemDxe)",      { 0xf4e5c7d0, 0xd239, 0x47cb, { 0xaa, 0xcd, 0x7f, 0x66, 0xef, 0x76, 0x32, 0x38 } } },
};

#define PROBE_COUNT  (sizeof (mProbes) / sizeof (mProbes[0]))


//
// keys100: 把内嵌在 FV 里的 EFI 应用（VermeerStage2App, FILE_GUID 2C9A63D4-...）
// 取出来用 LoadImage()/StartImage() 跑起来。这是「固件 -> EFI 应用」握手，
// 也是将来启动真正 UniXNU.efi 的同一条路。
//
STATIC VOID Say (CONST CHAR8 *Text);

STATIC CONST EFI_GUID mStage2AppGuid = {
  0x2c9a63d4, 0x8b17, 0x4e52, { 0xa6, 0xf1, 0x9d, 0x0c, 0x7b, 0x3e, 0x5a, 0x48 }
};

STATIC
VOID
LaunchEmbeddedApp (
  VOID
  )
{
  EFI_STATUS  Status;
  VOID        *Blob;
  UINTN       Size;
  EFI_HANDLE  NewHandle;
  CHAR8       Msg[128];

  Blob      = NULL;
  Size      = 0;
  NewHandle = NULL;

  Status = GetSectionFromAnyFv ((EFI_GUID *)&mStage2AppGuid, EFI_SECTION_PE32, 0, &Blob, &Size);
  AsciiSPrint (Msg, sizeof (Msg), "[STAGE2] fv blob=0x%lx size=%ld -> %r\n",
               (UINT64)(UINTN)Blob, (UINT64)Size, Status);
  Say (Msg);
  if (EFI_ERROR (Status) || (Blob == NULL)) {
    return;
  }

  Status = gBS->LoadImage (FALSE, gImageHandle, NULL, Blob, Size, &NewHandle);
  AsciiSPrint (Msg, sizeof (Msg), "[STAGE2] LoadImage -> %r\n", Status);
  Say (Msg);
  if (EFI_ERROR (Status)) {
    return;
  }

  Status = gBS->StartImage (NewHandle, NULL, NULL);
  AsciiSPrint (Msg, sizeof (Msg), "[STAGE2] StartImage -> %r (app returned)\n", Status);
  Say (Msg);
}

STATIC UINTN  mSkipUfsTest = 0;   // 1=跳过裸 UFS 直控测试
STATIC UINTN  mSkipMenu    = 1;   // keys99: 1=不进入阻塞式菜单（让派发继续到 UFSDxe）   // keys98: 1=跳过裸 UFS 直控测试

STATIC CONST CHAR8  mHeader[] =
  "\n"
  "==========================================================\n"
  " VermeerKeyProbeDxe: waiting for a key press\n"
  " Press VOLUME-UP / VOLUME-DOWN (or VOLUME-UP/ENTER).\n"
  "==========================================================\n";

STATIC UINTN  mKeyCount;
STATIC CHAR8  mLastLetter[PROBE_COUNT];
STATIC CHAR8  mLetterLine[PROBE_COUNT + 1];

/**
  'P' if the protocol exists right now, 'a' if not.

  Why a letter and not a word: the presence table is only a snapshot taken at our entry
  point.  The DXE dispatcher keeps installing drivers *after* us (we have DepEx TRUE), so the
  interesting thing is the TRANSITION over time.  Re-sampling it into one compact line every
  few seconds shows that transition without flooding the screen.
**/
STATIC
CHAR8
PresenceLetter (
  IN UINTN  Index
  )
{
  VOID  *Interface;

  Interface = NULL;
  if (EFI_ERROR (gBS->LocateProtocol (&mProbes[Index].Guid, NULL, &Interface))) {
    return 'a';
  }

  return 'P';
}

/**
  Print one line on every channel we have.
**/
STATIC
VOID
Say (
  IN CONST CHAR8  *Text
  )
{
  DEBUG ((DEBUG_ERROR, "%a", Text));
  if ((gST != NULL) && (gST->ConOut != NULL)) {
    CHAR16  Wide[128];
    UnicodeSPrint (Wide, sizeof (Wide), L"%a", Text);
    gST->ConOut->OutputString (gST->ConOut, Wide);
  }
}

/**
  The three-line menu shown on the panel.  It exists to prove that this firmware can be
  *operated* with the volume keys, not just that it prints.
**/
STATIC CONST CHAR8 *mMenuItems[5] = {
  "Boot Linux (UFS)",
  "Boot UniXNU",
  "Device information",
  "Reboot",
  "Power off"
};

#define MENU_COUNT  (sizeof (mMenuItems) / sizeof (mMenuItems[0]))

STATIC UINTN  mSelection;
STATIC UINTN  mCountdown;

STATIC
VOID
DrawMenu (
  VOID
  );

STATIC
VOID
PrintDeviceInfo (
  VOID
  )
{
  CHAR8         Line[160];
  UINTN         MapSize, MapKey, DescSize;
  UINT32        DescVersion;
  EFI_MEMORY_DESCRIPTOR  *Map;
  UINTN         Pages;
  UINTN         Index;
  UINT64        TotalPages;

  Say ("\n  [INFO] ---- vermeer platform ----\n");
  AsciiSPrint (Line, sizeof (Line), "  [INFO] firmware : %a\n", L"Project Silicium / vermeer (K70)");
  Say (Line);

  Map      = NULL;
  MapSize  = 0;
  MapKey   = 0;
  DescSize = 0;
  DescVersion = 0;
  if (!EFI_ERROR (gBS->GetMemoryMap (&MapSize, Map, &MapKey, &DescSize, &DescVersion))) {
    Say ("  [INFO] memory   : map readable\n");
  } else {
    Pages      = 0;
    TotalPages = 0;
    MapSize    = 0;
    gBS->GetMemoryMap (&MapSize, NULL, &MapKey, &DescSize, &DescVersion);
    Map = AllocatePool (MapSize + 4 * DescSize);
    if (Map != NULL) {
      if (!EFI_ERROR (gBS->GetMemoryMap (&MapSize, Map, &MapKey, &DescSize, &DescVersion))) {
        Pages = MapSize / DescSize;
        for (Index = 0; Index < Pages; Index++) {
          EFI_MEMORY_DESCRIPTOR  *D;

          D = (EFI_MEMORY_DESCRIPTOR *)((UINT8 *)Map + Index * DescSize);
          if (D->Type == EfiConventionalMemory) {
            TotalPages += D->NumberOfPages;
          }
        }

        AsciiSPrint (Line, sizeof (Line),
                     "  [INFO] memory   : %d descriptors, %d MiB free\n",
                     (UINT32)Pages, (UINT64)(TotalPages * 4 / 1024));
        Say (Line);
      }

      FreePool (Map);
    }
  }

  {
    UINTN         Handles;
    EFI_HANDLE    *List;

    Handles = 0;
    List    = NULL;
    if (!EFI_ERROR (gBS->LocateHandleBuffer (AllHandles, NULL, NULL, &Handles, &List))) {
      if (List != NULL) {
        gBS->FreePool (List);
      }
    }

    AsciiSPrint (Line, sizeof (Line),
                 "  [INFO] handles  : %d, ConIn=%a, keys seen=%d\n",
                 (UINT32)Handles,
                 (gST->ConIn != NULL) ? "yes" : "null",
                 (UINT32)mKeyCount);
    Say (Line);
  }

  Say ("  [INFO] press VOL-UP/DOWN to go back\n");
}

STATIC
VOID
ActivateSelection (
  VOID
  )
{
  switch (mSelection) {
    case 0:
      Say ("\n  [ACT] Boot Linux: needs a UFS block device, not available in this build.\n");
      break;
    case 1:
      Say ("\n  [ACT] Boot UniXNU: needs an ESP with \\EFI\\UniXNU, not available in this build.\n");
      break;
    case 2:
      PrintDeviceInfo ();
      break;
    case 3:
      Say ("\n  [ACT] ResetSystem (cold) ...\n");
      gBS->Stall (300 * 1000);
      gRT->ResetSystem (EfiResetCold, EFI_SUCCESS, 0, NULL);
      break;
    case 4:
      Say ("\n  [ACT] ResetSystem (shutdown) ...\n");
      gBS->Stall (300 * 1000);
      gRT->ResetSystem (EfiResetShutdown, EFI_SUCCESS, 0, NULL);
      break;
    default:
      break;
  }

  mCountdown = 0;
  DrawMenu ();
}

STATIC
VOID
DrawMenu (
  VOID
  )
{
  CHAR8  Line[128];
  UINTN  Index;

  Say ("\n  [UI] ==== Vermeer UEFI menu ====\n");
  for (Index = 0; Index < MENU_COUNT; Index++) {
    AsciiSPrint (
      Line,
      sizeof (Line),
      "  [UI]  %a %d. %a\n",
      (Index == mSelection) ? ">" : " ",
      (UINT32)(Index + 1),
      mMenuItems[Index]
      );
    Say (Line);
  }

  if (mCountdown > 0) {
    AsciiSPrint (
      Line,
      sizeof (Line),
      "  [UI]  acts in %d s unless you press a volume key (selected = %d)\n",
      (UINT32)mCountdown,
      (UINT32)(mSelection + 1)
      );
  } else {
    AsciiSPrint (
      Line,
      sizeof (Line),
      "  [UI]  VOL-UP / VOL-DOWN to move; it acts 3 s after the last key (selected = %d)\n",
      (UINT32)(mSelection + 1)
      );
  }

  Say (Line);
}

/**
  Drain one SimpleTextIn instance; returns TRUE if it produced a key.
**/
STATIC
BOOLEAN
DrainTextIn (
  IN EFI_SIMPLE_TEXT_INPUT_PROTOCOL  *TextIn,
  IN CONST CHAR8                     *Source
  )
{
  EFI_STATUS        Status;
  EFI_INPUT_KEY     Key;
  CHAR8             Line[96];
  BOOLEAN           Got;

  Got = FALSE;
  for (;;) {
    ZeroMem (&Key, sizeof (Key));
    Status = TextIn->ReadKeyStroke (TextIn, &Key);
    if (EFI_ERROR (Status)) {
      break;
    }

    mKeyCount++;
    AsciiSPrint (
      Line,
      sizeof (Line),
      "  KEY #%d from %a: ScanCode=0x%04x Unicode=0x%04x (%c)\n",
      mKeyCount,
      Source,
      (UINT32)Key.ScanCode,
      (UINT32)Key.UnicodeChar,
      (Key.UnicodeChar >= 0x20 && Key.UnicodeChar < 0x7f) ? (CHAR8)Key.UnicodeChar : '?'
      );
    Say (Line);

    if (Key.ScanCode == 0x01) {          // VOL-UP
      if (mSelection > 0) {
        mSelection--;
      }

      mCountdown = ACTION_DELAY_SECONDS;
      DrawMenu ();
    } else if (Key.ScanCode == 0x02) {   // VOL-DOWN
      if (mSelection + 1 < MENU_COUNT) {
        mSelection++;
      }

      mCountdown = ACTION_DELAY_SECONDS;
      DrawMenu ();
    }

    Got = TRUE;
  }

  return Got;
}

//
// ---- keys71: 裸机级 UFS 直读（移植自 ios-vermeer-lab xnu/vermeer/vermeer_ufs_probe.c）----
// 不依赖 DTBExtn / HALIOMMU / IOMMU 协议：直接按 UFSHCI 寄存器编程，轮询完成。
//
#define UFS_REG_BASE   0x01d84000U
#define SMMU_REG_BASE  0x15000000U
#define UFS_DMA_SIZE   0x8000U

STATIC VOID *mUfsDma;
STATIC UINT64 mUfsDmaPa;

STATIC
UINT32
UfsRd (
  IN UINT32  Off
  )
{
  return *(volatile UINT32 *)(UINTN)(UFS_REG_BASE + Off);
}

STATIC
VOID
UfsWr (
  IN UINT32  Off,
  IN UINT32  Val
  )
{
  *(volatile UINT32 *)(UINTN)(UFS_REG_BASE + Off) = Val;
  __asm__ volatile ("dsb sy" ::: "memory");
}

STATIC
UINT32
SmmuRd (
  IN UINT32  Off
  )
{
  return *(volatile UINT32 *)(UINTN)(SMMU_REG_BASE + Off);
}

STATIC
BOOLEAN
UfsWait (
  IN UINT32  Off,
  IN UINT32  Mask,
  IN UINT32  Expect,
  IN UINTN   Milliseconds
  )
{
  UINTN  i;

  for (i = 0; i < Milliseconds; i++) {
    if ((UfsRd (Off) & Mask) == Expect) {
      return TRUE;
    }
    gBS->Stall (1000);
    __asm__ volatile ("yield");
  }
  return (UfsRd (Off) & Mask) == Expect;
}

STATIC
VOID
UfsDmaSync (
  VOID
  )
{
  WriteBackDataCacheRange (mUfsDma, UFS_DMA_SIZE);
  __asm__ volatile ("dsb sy" ::: "memory");
}

STATIC
VOID
UfsPrint (
  IN CONST CHAR8  *Text
  )
{
  Say (Text);
}

//
// UFS75: UIC 命令（纯寄存器，无 DMA）—— 用来判断链路/设备是否还活着
//


STATIC
UINT32
UfsRdAddr (
  IN UINT64  Addr
  )
{
  return *(volatile UINT32 *)(UINTN)Addr;
}

STATIC
INT32
UfsUicCmd (
  IN  UINT32  Opcode,
  IN  UINT32  Arg1,
  IN  UINT32  Arg2,
  IN  UINT32  Arg3,
  OUT UINT32  *Res,
  OUT UINT32  *OutArg3
  )
{
  UINTN  i;

  UfsWr (0x94, Arg1);
  UfsWr (0x98, Arg2);
  UfsWr (0x9C, Arg3);
  UfsWr (0x90, (Opcode << 16) | 1);
  for (i = 0; i < 200; i++) {
    if ((UfsRd (0x90) & 1) == 0) {
      break;
    }
    gBS->Stall (1000);
  }
  *Res     = UfsRd (0x98);
  *OutArg3 = UfsRd (0x9C);
  return (i >= 200) ? 1 : 0;
}

//
// 一条 UPIU：opcode 0 = TUR, 0x28 = READ(10), 0x25 = READ CAPACITY(10)
//
STATIC
INT32
UfsScsi (
  IN  UINT8   Opcode,
  IN  UINTN   Length,
  IN  UINT32  Lba,
  OUT UINT32  *Ocs,
  OUT UINT8   *Status
  )
{
  STATIC UINT8  Tag;
  CHAR8         Line87[128];
  UINT8         *Dma   = (UINT8 *)mUfsDma;
  UINT8         *Cmd   = Dma + 0x1000;
  UINT32        *Utrd;
  UINT32        *Prdt;

  if ((UfsRd (0x58) & 1) != 0 ||
      UfsRd (0x50) != (UINT32)mUfsDmaPa ||
      UfsRd (0x54) != (UINT32)(mUfsDmaPa >> 32) ||
      UfsRd (0x60) != 1)
  {
    return 11;
  }

  ZeroMem (Dma, 32);
  ZeroMem (Cmd, 1040);
  if ((Opcode == 0x28) || (Opcode == 0x2a)) {
    ZeroMem (Dma + 0x4000, Length ? Length : 4096);
  }

  Cmd[0]  = 1;                                  // UPIU_COMMAND
  Cmd[1]  = Length ? 0x40 : 0;                  // R/W flags (read = 0x40)
  Cmd[2]  = 0;                                  // LUN 0
  Cmd[3]  = ++Tag;
  Cmd[12] = (UINT8)(Length >> 24);
  Cmd[13] = (UINT8)(Length >> 16);
  Cmd[14] = (UINT8)(Length >> 8);
  Cmd[15] = (UINT8)Length;
  Cmd[16] = Opcode;
  if ((Opcode == 0x28) || (Opcode == 0x2a)) {
    Cmd[18] = (UINT8)(Lba >> 24);
    Cmd[19] = (UINT8)(Lba >> 16);
    Cmd[20] = (UINT8)(Lba >> 8);
    Cmd[21] = (UINT8)Lba;
    Cmd[23] = (UINT8)((Length / 4096) >> 8);
    Cmd[24] = (UINT8)(Length / 4096);
  }

  Utrd        = (UINT32 *)Dma;
  Utrd[0]     = (1U << 28) | ((Length ? 2U : 0U) << 25) | (1U << 24);
  Utrd[2]     = 15;
  Utrd[4]     = (UINT32)(mUfsDmaPa + 0x1000);
  Utrd[5]     = (UINT32)((mUfsDmaPa + 0x1000) >> 32);
  Utrd[6]     = (128U << 16) | 128U;
  if (Length) {
    Utrd[7]   = (256U << 16) | 1U;
    Prdt      = (UINT32 *)(Cmd + 1024);
    Prdt[0]   = (UINT32)(mUfsDmaPa + 0x4000);
    Prdt[1]   = (UINT32)((mUfsDmaPa + 0x4000) >> 32);
    Prdt[2]   = 0;
    Prdt[3]   = (UINT32)(Length - 1);
  }

  UfsDmaSync ();
  AsciiSPrint (Line87, sizeof (Line87), "[UFS87] pre-doorbell 58=%08x 3c=%08x is=%08x 60=%08x\n",
               UfsRd (0x58), UfsRd (0x3C), UfsRd (0x20), UfsRd (0x60));
  UfsPrint (Line87);
  UfsWr (0x58, 1);
  AsciiSPrint (Line87, sizeof (Line87), "[UFS87] doorbell written, 58=%08x\n", UfsRd (0x58));
  UfsPrint (Line87);
  {
    UINTN  Poll;
    UINT32 OcsNow;
    for (Poll = 0; Poll < 2000; Poll++) {
      UINT32 Is = UfsRd (0x20);
      if ((Is & 0x00071880U) != 0) {
        AsciiSPrint (Line87, sizeof (Line87), "[UFS90] fatal IS=%08x 58=%08x\n", Is, UfsRd (0x58));
        UfsPrint (Line87);
        return 2;
      }
      OcsNow = (UINT32)(Utrd[2] & 0xFF);
      if (((UfsRd (0x58) & 1) == 0) && (OcsNow != 15)) {
        break;
      }
      gBS->Stall (1000);
    }
    AsciiSPrint (Line87, sizeof (Line87), "[UFS90] poll done: polls=%d 58=%08x is=%08x ocs=%02x\n",
                 (UINT32)Poll, UfsRd (0x58), UfsRd (0x20), (UINT32)(Utrd[2] & 0xFF));
    UfsPrint (Line87);
    if (Poll >= 2000) {
      AsciiSPrint (Line87, sizeof (Line87), "[UFS90] doorbell timeout 58=%08x 3c=%08x is=%08x\n",
                   UfsRd (0x58), UfsRd (0x3C), UfsRd (0x20));
      UfsPrint (Line87);
      return 1;
    }
  }
  InvalidateDataCacheRange (mUfsDma, UFS_DMA_SIZE);
  __asm__ volatile ("dsb sy" ::: "memory");

  *Ocs    = (UINT8)(Utrd[2] & 0xFF);
  *Status = *(UINT8 *)(Cmd + 512 + 7);
  return 0;
}

STATIC
VOID
UfsDirectTest (
  VOID
  )
{
  CHAR8   Line[128];
  UINT32  Ocs;
  UINT8   Status;
  UINT32  Guard;
  UINT32  OldLo;
  UINT32  OldHi;
  UINT32  OldRun;
  UINTN   Matches;
  UINTN   i;
  UINT32  Smr;
  UINT32  Mask;
  UINT8   *Data;
  INT32   Rc;
  EFI_STATUS Status2;

  UfsPrint ("[UFS71] ==== direct UFS probe (no IOMMU, no DT) ====\n");

  //
  // keys89: 不管本驱动排在哪，自己先把 UFS MMIO 窗口加进 GCD 并设为 UC
  //
  if (gDS != NULL) {
    EFI_STATUS  MapSt;
    MapSt = gDS->AddMemorySpace (EfiGcdMemoryTypeMemoryMappedIo, 0x01D80000ULL, 0x00020000ULL,
                                 EFI_MEMORY_UC | EFI_MEMORY_RUNTIME);
    AsciiSPrint (Line, sizeof (Line), "[UFS89] AddMemorySpace -> %r\n", MapSt);
    UfsPrint (Line);
    MapSt = gDS->SetMemorySpaceAttributes (0x01D80000ULL, 0x00020000ULL, EFI_MEMORY_UC);
    AsciiSPrint (Line, sizeof (Line), "[UFS89] SetMemorySpaceAttributes -> %r\n", MapSt);
    UfsPrint (Line);
  }

  {
    EFI_PHYSICAL_ADDRESS  MaxAddr;

    MaxAddr = 0xBE000000ULL;   // 必须在 0xc0000000 以下（vu_dma_allowed 的硬约束）
    Status2 = gBS->AllocatePages (AllocateMaxAddress, EfiBootServicesData, 12, &MaxAddr);
    if (EFI_ERROR (Status2)) {
      Status2 = gBS->AllocatePages (AllocateAnyPages, EfiBootServicesData, 12, &MaxAddr);
    }
    if (EFI_ERROR (Status2)) {
      UfsPrint ("[UFS71] alloc failed\n");
      return;
    }
    mUfsDma = (VOID *)(UINTN)MaxAddr;
  }
  //
  // 16 KiB 对齐（vu_dma_allowed 要求 pa & 0x3fff == 0）
  //
  mUfsDmaPa = ((UINT64)(UINTN)mUfsDma + 0x3FFF) & ~(UINT64)0x3FFF;
  ZeroMem ((VOID *)(UINTN)mUfsDmaPa, UFS_DMA_SIZE);
  UfsDmaSync ();

  AsciiSPrint (Line, sizeof (Line), "[UFS71] dma=0x%lx size=0x%x\n", (UINT64)mUfsDmaPa, UFS_DMA_SIZE);
  UfsPrint (Line);
  if ((mUfsDmaPa & 0x3fff) != 0 || mUfsDmaPa >= 0xc0000000ULL) {
    UfsPrint ("[UFS71] dma outside 4G-low window - stop\n");
    return;
  }

  //
  // SMMU 身份映射自检（照抄 identity_candidate）
  //
  Guard = 0;

  //
  // keys95: 把 SMMU 的五个判据全部打出来（先前只有一个合成的 guard 值，无法定位）
  //
  AsciiSPrint (Line, sizeof (Line),
               "[UFS95] smmu idr0=%08x idr1=%08x cr0=%08x smr0=%08x s2cr0=%08x id2=%08x\n",
               SmmuRd (0x20), SmmuRd (0x24), SmmuRd (0x00), SmmuRd (0x800),
               SmmuRd (0xc00), SmmuRd (0x28));
  UfsPrint (Line);
  AsciiSPrint (Line, sizeof (Line),
               "[UFS95] smmu ctx0=%08x cb0=%08x gbpa=%08x\n",
               SmmuRd (0x1000), SmmuRd (0x80000), SmmuRd (0x1008));
  UfsPrint (Line);

  if ((SmmuRd (0x20) != 0x4c017e69) || (SmmuRd (0x24) != 0x60000046) ||
      (SmmuRd (0x00) != 0x00280406) || (SmmuRd (0x800) != 0x80000060) ||
      (SmmuRd (0xc00) != 0))
  {
    Guard = 1;
  } else {
    Matches = 0;
    for (i = 0; i < 105; i++) {
      Smr  = SmmuRd (0x800 + 4 * i);
      Mask = (Smr >> 16) & 0x7fff;
      if (((Smr & (1U << 31)) != 0) && ((Smr ^ 0x60) & ~Mask & 0xffff) == 0) {
        Matches++;
      }
    }
    if ((Matches != 1) || (((SmmuRd (0x1000) >> 16) & 3) != 1) || ((SmmuRd (0x80000) & 1) != 0)) {
      Guard = 2;
    }
  }
  AsciiSPrint (Line, sizeof (Line), "[UFS71] smmu guard (0=ok)=%d  id2=0x%x\n", Guard, SmmuRd (0x28));
  UfsPrint (Line);

  if (Guard != 0) {
    //
    // keys97: SMMUEN=0（CR0.bit0=0）时 DMA 是直通的，guard 只是"配置与某环境不符"，
    // 不能当致命错误；只告警继续，让后续流程跑完。
    //
    UfsPrint ("[UFS97] smmu guard != 0 but SMMUEN=0 -> continue (bypass)\n");
  }

  //
  // 主机空闲检查
  //
  if (((UfsRd (0x30) & 15) != 15) || (UfsRd (0x34) != 1) ||
      ((UfsRd (0x58) & 1) != 0) || (UfsRd (0x78) != 0) || (UfsRd (0x24) != 0))
  {
    AsciiSPrint (Line, sizeof (Line), "[UFS71] host not idle: 30=%x 34=%x 58=%x 78=%x 24=%x\n",
                 UfsRd (0x30), UfsRd (0x34), UfsRd (0x58), UfsRd (0x78), UfsRd (0x24));
    UfsPrint (Line);
    UfsPrint ("[UFS71] STOP (host busy) - no command sent\n");
    return;
  }
  UfsPrint ("[UFS71] host idle ok\n");

  //
  // keys90: 照 UniXNU NativeUfs 的做法，只读 GCC 里 UFS 的电源/时钟状态。
  // GDSCR bit31 = PWR_ON；CBCR bit31 = CLK_OFF。写入不做（语义未验证）。
  //
  if (gDS != NULL) {
    EFI_STATUS  GccSt;
    GccSt = gDS->AddMemorySpace (EfiGcdMemoryTypeMemoryMappedIo, 0x00100000ULL, 0x00100000ULL,
                                 EFI_MEMORY_UC | EFI_MEMORY_RUNTIME);
    AsciiSPrint (Line, sizeof (Line), "[UFS90] gcc map -> %r\n", GccSt);
    UfsPrint (Line);
    if (1) {
      gDS->SetMemorySpaceAttributes (0x00100000ULL, 0x00100000ULL, EFI_MEMORY_UC);
      AsciiSPrint (Line, sizeof (Line),
                   "[UFS90] gcc gdscr=%08x mem_phy_gdscr=%08x axi=%08x ahb=%08x unipro=%08x\n",
                   UfsRdAddr (0x00100000ULL + 0x77004), UfsRdAddr (0x00100000ULL + 0x9e000),
                   UfsRdAddr (0x00100000ULL + 0x77018), UfsRdAddr (0x00100000ULL + 0x77024),
                   UfsRdAddr (0x00100000ULL + 0x77068));
      UfsPrint (Line);
      AsciiSPrint (Line, sizeof (Line),
                   "[UFS90] gcc tx0=%08x rx0=%08x aux=%08x rx1=%08x aggre=%08x\n",
                   UfsRdAddr (0x00100000ULL + 0x77028), UfsRdAddr (0x00100000ULL + 0x7702c),
                   UfsRdAddr (0x00100000ULL + 0x770b0), UfsRdAddr (0x00100000ULL + 0x770cc),
                   UfsRdAddr (0x00100000ULL + 0x770e4));
      UfsPrint (Line);
    }
  }

  //
  // keys87: 照抄 ios-vermeer-lab 的顺序 —— 先停 transfer list，再清 DMA，再接管
  //
  {
    UINT32 StopTries = 0;
    UfsWr (0x60, 0);
    while (((UfsRd (0x60) & 1) != 0) && (StopTries < 1000)) {
      gBS->Stall (1000);
      StopTries++;
    }
    AsciiSPrint (Line, sizeof (Line), "[UFS87] run-stop wait: 60=%08x tries=%d\n", UfsRd (0x60), (UINT32)StopTries);
    UfsPrint (Line);
    if ((UfsRd (0x60) & 1) != 0) {
      UfsPrint ("[UFS87] transfer list did not stop - abort\n");
      return;
    }
    ZeroMem ((VOID *)(UINTN)mUfsDmaPa, 0x6000);
    UfsDmaSync ();
    UfsPrint ("[UFS87] dma zeroed (0x6000) + flushed\n");
  }

#if defined (UFS74_DUMPONLY)
  {
    UINT32  o;
    for (o = 0x00; o <= 0x80; o += 4) {
      AsciiSPrint (Line, sizeof (Line), "[UFS74] r%02x=%08x\n", o, UfsRd (o));
      UfsPrint (Line);
    }
    for (o = 0x00; o <= 0x30; o += 4) {
      AsciiSPrint (Line, sizeof (Line), "[UFS74] smmu%03x=%08x\n", o, SmmuRd (o));
      UfsPrint (Line);
    }
    AsciiSPrint (Line, sizeof (Line), "[UFS74] cap=%08x cards=%08x smmu_id2=%08x\n",
                 UfsRd (0x00), UfsRd (0x24), SmmuRd (0x28));
    UfsPrint (Line);
    UfsPrint ("[UFS74] DUMP ONLY - no doorbell, rebooting is safe\n");
    return;
  }
#endif

  //
  // UFS75: 只做 UIC（不发门铃）
  //
  {
    UINT32  Res;
    UINT32  Out3;
    INT32   Rc;

    AsciiSPrint (Line, sizeof (Line), "[UFS75] before: IS=%08x HCS=%08x IE=%08x\n",
                 UfsRd (0x20), UfsRd (0x30), UfsRd (0x24));
    UfsPrint (Line);

    Rc = UfsUicCmd (0x01, 0x00, 0, 0, &Res, &Out3);
    AsciiSPrint (Line, sizeof (Line), "[UFS75] DME_GET(0x00) rc=%d res=%08x arg3=%08x\n", (UINT32)Rc, Res, Out3);
    UfsPrint (Line);

    Rc = UfsUicCmd (0x01, 0x02, 0, 0, &Res, &Out3);
    AsciiSPrint (Line, sizeof (Line), "[UFS75] DME_GET(0x02) rc=%d res=%08x arg3=%08x\n", (UINT32)Rc, Res, Out3);
    UfsPrint (Line);

    Rc = UfsUicCmd (0x01, 0x04, 0, 0, &Res, &Out3);
    AsciiSPrint (Line, sizeof (Line), "[UFS75] DME_GET(0x04) rc=%d res=%08x arg3=%08x\n", (UINT32)Rc, Res, Out3);
    UfsPrint (Line);

    Rc = UfsUicCmd (0x04, 0, 0, 0, &Res, &Out3);
    AsciiSPrint (Line, sizeof (Line), "[UFS75] LINK_STARTUP rc=%d res=%08x\n", (UINT32)Rc, Res);
    UfsPrint (Line);

    AsciiSPrint (Line, sizeof (Line), "[UFS75] after: IS=%08x HCS=%08x UECPA=%08x\n",
                 UfsRd (0x20), UfsRd (0x30), UfsRd (0x38));
    UfsPrint (Line);
    UfsPrint ("[UFS75] UIC DONE\n");

    {
      UINT32  Uecpa = UfsRd (0x64);
      UINTN   Try;
      for (Try = 0; Try < 200; Try++) {
        Uecpa = UfsRd (0x64);
        if ((Uecpa & 1) != 0) {
          break;
        }
        gBS->Stall (1000);
      }

      AsciiSPrint (Line, sizeof (Line), "[UFS106] UECPA=%08x link_up=%d tries=%d\n",
                   Uecpa, (Uecpa & 1) ? 1 : 0, (UINT32)Try);
      UfsPrint (Line);

      if ((Uecpa & 1) == 0) {
        UfsPrint ("[UFS106] PA_LINKUP=0 - UniPro link is down, DO NOT ring doorbell (safe stop)\n");
        return;
      }
    }

  }

  //
  // keys94: UFS79 主机复位实验禁用——HCE=1 之后 UCRDY 不会自己回来，
  // 会把后面的 takeover / TUR 测试整个挡住。
  UfsPrint ("[UFS94] host reset skipped (UFS79 experiment disabled)\n");

  //
  // 接管 transfer list
  //
  OldLo  = UfsRd (0x50);
  OldHi  = UfsRd (0x54);
  OldRun = UfsRd (0x60);
  UfsWr (0x60, 0);
  if (!UfsWait (0x60, 1, 0, 1000)) {
    UfsPrint ("[UFS71] transfer list did not stop - stop\n");
    return;
  }
  UfsWr (0x50, (UINT32)mUfsDmaPa);
  UfsWr (0x54, (UINT32)(mUfsDmaPa >> 32));
  UfsWr (0x60, 1);
  if ((UfsRd (0x50) != (UINT32)mUfsDmaPa) ||
      (UfsRd (0x54) != (UINT32)(mUfsDmaPa >> 32)) || (UfsRd (0x60) != 1))
  {
    UfsPrint ("[UFS71] our list not accepted - stop\n");
    return;
  }
  UfsPrint ("[UFS71] own descriptors accepted\n");

  //
  // TUR
  //
  UfsPrint ("[UFS71] sending TUR (first doorbell)...\n");
  Ocs    = 0xFF;
  Status = 0xFF;
  Rc     = UfsScsi (0, 0, 0, &Ocs, &Status);
  AsciiSPrint (Line, sizeof (Line), "[UFS71] TUR   rc=%d ocs=0x%x status=0x%x\n", (UINT32)Rc, Ocs, Status);
  UfsPrint (Line);

  //
  // READ CAPACITY(10) -> LBA0 的 DMA 缓冲里拿到最大 LBA
  //
  Ocs    = 0xFF;
  Status = 0xFF;
  Rc     = UfsScsi (0x25, 8, 0, &Ocs, &Status);
  AsciiSPrint (Line, sizeof (Line), "[UFS71] RCAP  rc=%d ocs=0x%x status=0x%x\n", (UINT32)Rc, Ocs, Status);
  UfsPrint (Line);

  //
  // READ(10) LBA0, 1 个 4K 块 -> 里面应当有 GPT 头里的 "EFI PART"
  //
  Ocs    = 0xFF;
  Status = 0xFF;
  Rc     = UfsScsi (0x28, 4096, 0, &Ocs, &Status);
  Data   = (UINT8 *)(UINTN)(mUfsDmaPa + 0x4000);
  AsciiSPrint (Line, sizeof (Line), "[UFS71] READ0 rc=%d ocs=0x%x status=0x%x\n", (UINT32)Rc, Ocs, Status);
  UfsPrint (Line);
  AsciiSPrint (Line, sizeof (Line), "[UFS71] sig@0x200= %c%c%c%c%c%c%c%c  mbr=%02x%02x\n",
               Data[0x200], Data[0x201], Data[0x202], Data[0x203],
               Data[0x204], Data[0x205], Data[0x206], Data[0x207],
               Data[0x1FE], Data[0x1FF]);
  UfsPrint (Line);
  AsciiSPrint (Line, sizeof (Line), "[UFS71] data[0..7]= %02x %02x %02x %02x %02x %02x %02x %02x\n",
               Data[0], Data[1], Data[2], Data[3], Data[4], Data[5], Data[6], Data[7]);
  UfsPrint (Line);

  //
  // 还回原 transfer list（若还在忙就不动，避免二次请求）
  //
  if ((UfsRd (0x58) & 1) == 0) {
    UfsWr (0x60, 0);
    if (UfsWait (0x60, 1, 0, 1000)) {
      UfsWr (0x50, OldLo);
      UfsWr (0x54, OldHi);
      UfsWr (0x60, OldRun);
      UfsPrint ("[UFS71] firmware list restored\n");
    }
  }
  UfsPrint ("[UFS71] ==== direct UFS probe end ====\n");
}

/**
  Entry point.
**/
EFI_STATUS
EFIAPI
VermeerKeyProbeDxeEntry (
  IN EFI_HANDLE        ImageHandle,
  IN EFI_SYSTEM_TABLE  *SystemTable
  )
{
  EFI_STATUS                      Status;
  UINTN                           Index;
  UINTN                           Alive;
  VOID                            *Interface;
  CHAR8                           Line[96];
  EFI_EVENT                       Timer;
  EFI_HANDLE                      *HandleList;
  EFI_SIMPLE_TEXT_INPUT_PROTOCOL  *TextIn;
  UINTN                           HandleCount;

  Say (mHeader);

  if (mSkipUfsTest == 0) { UfsDirectTest (); }   // keys98: 跳过裸 UFS 测试

  //
  // keys88: 让屏上最后一段永远是我们自己的 UFS 结果，便于拍照判读
  //
  // keys97: 不再死循环，让派发继续（UFSDxe 要走 SMMU 桩）
  Say ("  === UFS TEST END (keys97, dispatch continues) ===\n");

  //
  // 1. Which vendor protocols exist?  A DepEx-gated driver that cannot dispatch leaves no
  //    trace at all, so this table is the only way to tell "skipped" from "ran and failed".
  //
  Say ("  vendor protocol presence:\n");
  for (Index = 0; Index < KEYPROBE_ARRAY_SIZE (mProbes); Index++) {
    Interface = NULL;
    Status    = gBS->LocateProtocol (&mProbes[Index].Guid, NULL, &Interface);
    AsciiSPrint (Line, sizeof (Line), "    %-22a %a\n",
                 mProbes[Index].Name, EFI_ERROR (Status) ? "absent" : "PRESENT");
    Say (Line);
  }

  //
  // 2. Report the console path, then poll every SimpleTextIn we can find plus gST->ConIn.
  //
  AsciiSPrint (Line, sizeof (Line), "  ConIn=%a ConOut=%a\n",
               ((gST != NULL) && (gST->ConIn != NULL))  ? "yes" : "null",
               ((gST != NULL) && (gST->ConOut != NULL)) ? "yes" : "null");
  Say (Line);
  Say ("  listening...\n");
  mSelection = 0;
  mCountdown = 0;
  DrawMenu ();

  gBS->CreateEvent (EVT_TIMER, TPL_APPLICATION, NULL, NULL, &Timer);
  if (Timer != NULL) {
    gBS->SetTimer (Timer, TimerRelative, ALIVE_INTERVAL_US);
  }

  Alive = 0;
  if (mSkipMenu != 0) {
    Say ("  [UI] menu skipped (keys99) - dispatch continues\n");
    LaunchEmbeddedApp ();
    return EFI_SUCCESS;
  }

  for (;;) {
    //
    // gST->ConIn (the ConSplitter aggregate) first.
    //
    if ((gST != NULL) && (gST->ConIn != NULL)) {
      DrainTextIn (gST->ConIn, "ConIn");
    }

    //
    // Then every individual SimpleTextIn, in case the splitter has not aggregated a
    // newly published one yet.
    //
    HandleList  = NULL;
    HandleCount = 0;
    Status      = gBS->LocateHandleBuffer (
                         ByProtocol,
                         &gEfiSimpleTextInProtocolGuid,
                         NULL,
                         &HandleCount,
                         &HandleList
                         );
    if (!EFI_ERROR (Status) && (HandleList != NULL)) {
      for (Index = 0; Index < HandleCount; Index++) {
        TextIn = NULL;
        if (!EFI_ERROR (gBS->HandleProtocol (HandleList[Index], &gEfiSimpleTextInProtocolGuid, (VOID **)&TextIn)) &&
            (TextIn != NULL))
        {
          DrainTextIn (TextIn, "TextIn");
        }
      }

      gBS->FreePool (HandleList);
    }

    //
    // WaitForEvent pumps the DXE event loop properly (a bare Stall loop would still work on
    // this timer interrupt driven platform, but this is the correct call at TPL_APPLICATION).
    //
    if (Timer != NULL) {
      UINTN                     Signalled;
      EFI_EVENT                 Events[2];
      UINTN                     EventCount;

      EventCount = 0;
      Events[EventCount++] = Timer;
      if ((gST != NULL) && (gST->ConIn != NULL) && (gST->ConIn->WaitForKey != NULL)) {
        Events[EventCount++] = gST->ConIn->WaitForKey;
      }

      Signalled = 0;
      gBS->WaitForEvent (EventCount, Events, &Signalled);
      if ((EventCount == 1) || (Signalled == 0)) {
        UINTN       TextInCount;
        EFI_HANDLE  *Handles;

        Alive++;

        //
        // Re-sample the vendor protocols and the number of SimpleTextIn instances.  A driver
        // that dispatches after us shows up here as an 'a' turning into a 'P'; the button
        // driver additionally adds one SimpleTextIn instance of its own.
        //
        Handles = NULL;
        TextInCount = 0;
        if (!EFI_ERROR (gBS->LocateHandleBuffer (ByProtocol, &gEfiSimpleTextInProtocolGuid,
                                                NULL, &TextInCount, &Handles)))
        {
          if (Handles != NULL) {
            gBS->FreePool (Handles);
          }
        } else {
          TextInCount = 0;
        }

        {
          UINTN    Index;
          BOOLEAN  Changed;

          //
          // Record the chain state and leave a permanent line behind whenever it changes.
          // The device has no serial port and a crash wipes the screen, so the only way to
          // keep the history is to append a line at the moment of the transition.
          //
          Changed = FALSE;
          for (Index = 0; Index < PROBE_COUNT; Index++) {
            CHAR8 Letter;

            Letter = PresenceLetter (Index);
            if (Letter != mLastLetter[Index]) {
              mLastLetter[Index] = Letter;
              Changed            = TRUE;
            }

            mLetterLine[Index] = Letter;
          }

          mLetterLine[PROBE_COUNT] = 0;
          if (Changed) {
            AsciiSPrint (Line, sizeof (Line), "\n  [%3d s] chain: %a\n", Alive, mLetterLine);
            Say (Line);
          }
        }

        if (mCountdown > 0) {
          mCountdown--;
          if (mCountdown == 0) {
            ActivateSelection ();
          } else {
            DrawMenu ();
          }
        }

        AsciiSPrint (Line, sizeof (Line),
                     "\r  t=%3d s  chain=%a  txtin=%d  keys=%d   ",
                     Alive,
                     mLetterLine,
                     TextInCount,
                     mKeyCount);
        Say (Line);
        gBS->SetTimer (Timer, TimerRelative, ALIVE_INTERVAL_US);
      }
    } else {
      gBS->Stall (50 * 1000);
    }
  }

  return EFI_SUCCESS;
}
