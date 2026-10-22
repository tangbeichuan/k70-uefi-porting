/** @file
  VermeerLogDiskDxe - expose a tiny RAM "disk" that holds a real FAT volume, so
  that the vendor USB mass-storage gadget (UsbMsdDxe) can present it to a PC as
  an ordinary removable drive containing BOOTLOG.TXT.  This is the "stop
  photographing the screen" path: mount the volume on Windows, copy the file.

  Volume geometry (1 MiB media, unchanged BlockIO parameters):
    512 B sectors, 2048 sectors total
    1 reserved sector, 1 FAT, 32 root-directory entries, 4 sectors/cluster
    -> FAT = 2 sectors, root dir = 2 sectors, data starts at LBA 5
    -> 510 data clusters
    root[0] = volume label "K70 LOGDISK", root[1] = BOOTLOG.TXT

  The file's cluster chain is grown one cluster at a time as lines are appended
  (always EOC-terminated, always exactly as long as the data needs), so the
  volume stays strictly consistent: dosfsck/fsck.fat and Windows chkdsk find
  nothing to repair.  BOOTLOG.TXT is capped at FAT_MAX_FILE_CLUSTERS clusters;
  once full, appends are dropped (the first lines of a boot are never lost).

  IMPORTANT - FAT12 vs FAT16:
  The FAT specification (fatgen103) and Windows fastfat decide the on-disk type
  *only* from the data-cluster count: < 4085 clusters => FAT12, 4085..65524 =>
  FAT16.  A 1 MiB volume cannot reach 4085 clusters (it has 2048 sectors), so
  this volume is physically FAT12: writing 16-bit FAT entries here would make
  Windows interpret them as 12-bit and corrupt/garble the file.  The formatter
  below therefore derives the entry width from the computed cluster count and
  emits either a valid FAT12 or a valid FAT16 volume.  Raise LOGDISK_BYTES to
  8 MiB (keep 4 sectors/cluster) and the same code produces a genuine FAT16
  volume with 4091 clusters; BOOTLOG.TXT logic is unchanged.
**/

#include <Uefi.h>
#include <Library/UefiBootServicesTableLib.h>
#include <Library/UefiLib.h>
#include <Library/DebugLib.h>
#include <Library/MemoryAllocationLib.h>
#include <Library/BaseMemoryLib.h>
#include <Library/BaseLib.h>
#include <Protocol/BlockIo.h>
#include <Protocol/DevicePath.h>

//
// keys147d diagnostics: after BDS has run, report whether the Qualcomm USB
// device stack actually started.  The decisive evidence is the presence of
// gEfiUsbFunctionIoProtocolGuid (32D2963A...), which UsbfnDwc3Dxe installs in
// its DriverBinding.Start(); QcomUsbConfigProtocol (E722B03F...) is installed
// earlier by UsbConfigDxe, so its presence alone does NOT prove the controller
// started.  If UsbFnIo is missing we explicitly ConnectController() every
// QcomUsbConfig handle and re-check, which distinguishes "never bound" from
// "bound but Start failed".
//
#define VERMEER_USB_DIAG 1

STATIC CONST EFI_GUID  mQcomUsbConfigGuid = {
  0xE722B03F, 0xB250, 0x42CE, { 0x8E, 0xBD, 0x5B, 0xD5, 0x18, 0x12, 0xD0, 0x37 }
};
STATIC CONST EFI_GUID  mUsbFnIoGuid = {
  0x32D2963A, 0xFE5D, 0x4F30, { 0xB6, 0x33, 0x6E, 0x5D, 0xC5, 0x58, 0x03, 0xCC }
};

//
// keys148: corrected DWC3 register offsets (keys147d used 0xC700 as DCTL and
// 0xC704 as DSTS, i.e. four bytes low - the RUN_STOP bit landed in DCFG).
//
#define DWC3_BASE_DIAG       0x0A600000ULL
#define DWC3_GCTL_DIAG       0xC110U
#define DWC3_GSTS_DIAG       0xC118U
#define DWC3_GSNPSID_DIAG    0xC120U
#define DWC3_GUSB2PHYCFG_DIAG 0xC200U
#define DWC3_DCFG_DIAG       0xC700U
#define DWC3_DCTL_DIAG       0xC704U
#define DWC3_DEVTEN_DIAG     0xC708U
#define DWC3_DSTS_DIAG       0xC70CU
#define DWC3_DCTL_RUN_STOP   (1U << 31)
#define DWC3_DSTS_DEVCTRLHLT (1U << 22)

STATIC EFI_EVENT  mUsbDiagEvent = NULL;
STATIC EFI_EVENT  mUsbFnIoEvent = NULL;
STATIC VOID      *mUsbFnIoReg   = NULL;

STATIC
VOID
UsbDiagDumpDwc3 (
  IN CONST CHAR8  *Tag
  )
{
  UINT32  Gsnpsid, Gctl, Gsts, GPhy, Dcfg, Dctl, Devten, Dsts;

  Gsnpsid = *(volatile UINT32 *)(UINTN)(DWC3_BASE_DIAG + DWC3_GSNPSID_DIAG);
  Gctl    = *(volatile UINT32 *)(UINTN)(DWC3_BASE_DIAG + DWC3_GCTL_DIAG);
  Gsts    = *(volatile UINT32 *)(UINTN)(DWC3_BASE_DIAG + DWC3_GSTS_DIAG);
  GPhy    = *(volatile UINT32 *)(UINTN)(DWC3_BASE_DIAG + DWC3_GUSB2PHYCFG_DIAG);
  Dcfg    = *(volatile UINT32 *)(UINTN)(DWC3_BASE_DIAG + DWC3_DCFG_DIAG);
  Dctl    = *(volatile UINT32 *)(UINTN)(DWC3_BASE_DIAG + DWC3_DCTL_DIAG);
  Devten  = *(volatile UINT32 *)(UINTN)(DWC3_BASE_DIAG + DWC3_DEVTEN_DIAG);
  Dsts    = *(volatile UINT32 *)(UINTN)(DWC3_BASE_DIAG + DWC3_DSTS_DIAG);

  DEBUG ((
    DEBUG_ERROR,
    "[USBDIAG] DWC3[%a] GSNPSID=%08x GCTL=%08x GSTS=%08x GUSB2PHYCFG=%08x DCFG=%08x DCTL=%08x DEVTEN=%08x DSTS=%08x\n",
    Tag, Gsnpsid, Gctl, Gsts, GPhy, Dcfg, Dctl, Devten, Dsts
    ));
  DEBUG ((
    DEBUG_ERROR,
    "[USBDIAG] DWC3[%a] dec: run_stop=%d csfrst=%d phy_susphy=%d hlt22=%d hlt31=%d speed=%d linkst=%d sssts=%d\n",
    Tag,
    (Dctl >> 31) & 1,
    (Dctl >> 30) & 1,
    (GPhy >> 6) & 1,
    (Dsts >> 22) & 1,
    (Dsts >> 31) & 1,
    Dsts & 7,
    (Dsts >> 18) & 0xF,
    (Dsts >> 24) & 7
    ));
}

STATIC
VOID
UsbDiagEnsureRun (
  VOID
  )
{
  UINT32  Dctl, Dsts, GPhy, N;

  Dctl = *(volatile UINT32 *)(UINTN)(DWC3_BASE_DIAG + DWC3_DCTL_DIAG);
  Dsts = *(volatile UINT32 *)(UINTN)(DWC3_BASE_DIAG + DWC3_DSTS_DIAG);

  if (((Dsts & DWC3_DSTS_DEVCTRLHLT) == 0) && ((Dctl & DWC3_DCTL_RUN_STOP) != 0)) {
    DEBUG ((DEBUG_ERROR, "[USBDIAG] DWC3 already running, no action\n"));
    return;
  }

  //
  // Late bring-up: this runs after BDS loaded the whole USB stack, so the
  // vendor drivers have had their chance to start the gadget.  Only release
  // the halt here (no core soft reset), matching the ios-vermeer-lab sequence.
  //
  GPhy = *(volatile UINT32 *)(UINTN)(DWC3_BASE_DIAG + DWC3_GUSB2PHYCFG_DIAG);
  GPhy &= ~((1U << 6) | (1U << 8));   /* SUSPHY, ENBLSLPM */
  *(volatile UINT32 *)(UINTN)(DWC3_BASE_DIAG + DWC3_GUSB2PHYCFG_DIAG) = GPhy;

  Dctl = *(volatile UINT32 *)(UINTN)(DWC3_BASE_DIAG + DWC3_DCTL_DIAG);
  *(volatile UINT32 *)(UINTN)(DWC3_BASE_DIAG + DWC3_DCTL_DIAG) = Dctl | DWC3_DCTL_RUN_STOP;

  for (N = 0; N < 200; N++) {
    Dsts = *(volatile UINT32 *)(UINTN)(DWC3_BASE_DIAG + DWC3_DSTS_DIAG);
    if ((Dsts & DWC3_DSTS_DEVCTRLHLT) == 0) {
      break;
    }

    gBS->Stall (1000);
  }

  DEBUG ((
    DEBUG_ERROR,
    "[USBDIAG] DWC3 late run: DCTL=%08x DSTS=%08x polls=%d hlt22=%d\n",
    *(volatile UINT32 *)(UINTN)(DWC3_BASE_DIAG + DWC3_DCTL_DIAG),
    Dsts,
    N,
    (Dsts >> 22) & 1
    ));
}

STATIC
VOID
EFIAPI
UsbFnIoNotify (
  IN EFI_EVENT  Event,
  IN VOID      *Context
  )
{
  EFI_STATUS  Status;
  VOID       *Ifc;

  (VOID)Event;
  (VOID)Context;

  Ifc    = NULL;
  Status = gBS->LocateProtocol ((EFI_GUID *)&mUsbFnIoGuid, NULL, &Ifc);
  DEBUG ((DEBUG_ERROR, "[USBDIAG] UsbFnIo notify: status=%r iface=%p  <-- controller STARTED\n", Status, Ifc));
}

STATIC
VOID
EFIAPI
UsbDiagTimerCallback (
  IN EFI_EVENT  Event,
  IN VOID      *Context
  )
{
  EFI_STATUS  Status;
  VOID       *Ifc;
  UINTN       Count;
  UINTN       Index;
  EFI_HANDLE *Handles;
  UINT32      Reg88;
  UINT32      Reg8C;

  (VOID)Event;
  (VOID)Context;

  DEBUG ((DEBUG_ERROR, "[USBDIAG] ---- USB device-stack probe ----\n"));

  Ifc = NULL;
  Status = gBS->LocateProtocol ((EFI_GUID *)&mQcomUsbConfigGuid, NULL, &Ifc);
  DEBUG ((DEBUG_ERROR, "[USBDIAG] LocateProtocol(QcomUsbConfig)=%r iface=%p\n", Status, Ifc));
  if (!EFI_ERROR (Status) && (Ifc != NULL)) {
    Reg88 = *(volatile UINT32 *)((UINT8 *)Ifc + 0x88);
    Reg8C = *(volatile UINT32 *)((UINT8 *)Ifc + 0x8C);
    DEBUG ((DEBUG_ERROR, "[USBDIAG] iface+0x88=%08x iface+0x8c=%08x (UsbfnDwc3.Supported needs <=3 and ==4)\n", Reg88, Reg8C));
  }

  //
  // keys148: corrected DWC3 snapshot + a late "release halt" attempt.  This
  // timer fires after BDS finished loading the driver list, so if the vendor
  // stack never set DCTL.RUN_STOP we can still un-halt the controller here.
  //
  UsbDiagDumpDwc3 ("probe");
  UsbDiagEnsureRun ();
  UsbDiagDumpDwc3 ("post-run");

  Ifc  = NULL;
  Status = gBS->LocateProtocol ((EFI_GUID *)&mUsbFnIoGuid, NULL, &Ifc);
  DEBUG ((DEBUG_ERROR, "[USBDIAG] LocateProtocol(UsbFnIo)=%r iface=%p  <-- controller STARTED if Success\n", Status, Ifc));

  Handles = NULL;
  Count   = 0;
  Status  = gBS->LocateHandleBuffer (
                   ByProtocol,
                   (EFI_GUID *)&mQcomUsbConfigGuid,
                   NULL,
                   &Count,
                   &Handles
                   );
  DEBUG ((DEBUG_ERROR, "[USBDIAG] QcomUsbConfig handles=%d status=%r\n", (UINT32)Count, Status));
  if (EFI_ERROR (Status)) {
    Handles = NULL;
    Count   = 0;
  }

  if (EFI_ERROR (gBS->LocateProtocol ((EFI_GUID *)&mUsbFnIoGuid, NULL, &Ifc))) {
    for (Index = 0; Index < Count; Index++) {
      Status = gBS->ConnectController (Handles[Index], NULL, NULL, FALSE);
      DEBUG ((DEBUG_ERROR, "[USBDIAG] ConnectController(handle[%d]=%p)=%r\n", (UINT32)Index, Handles[Index], Status));
    }

    Ifc    = NULL;
    Status = gBS->LocateProtocol ((EFI_GUID *)&mUsbFnIoGuid, NULL, &Ifc);
    DEBUG ((DEBUG_ERROR, "[USBDIAG] after ConnectController: UsbFnIo=%r iface=%p\n", Status, Ifc));
    UsbDiagEnsureRun ();
    UsbDiagDumpDwc3 ("post-connect");
  }

  if (Handles != NULL) {
    FreePool (Handles);
  }

  DEBUG ((DEBUG_ERROR, "[USBDIAG] ---- probe end ----\n"));
}

#define LOGDISK_BYTES       (1024U * 1024U)   /* 1 MiB RAM log disk              */
#define LOGDISK_BLOCK       512U
#define LOGDISK_BLOCKS      (LOGDISK_BYTES / LOGDISK_BLOCK)

//
// FAT volume geometry parameters (deliberately the smallest interesting set:
// one reserved sector, one FAT, 32 root entries, 4 sectors per cluster).
//
#define FAT_RSVD_SEC        1U
#define FAT_NUM_FATS        1U
#define FAT_ROOT_ENTRIES    32U
#define FAT_SEC_PER_CLUS    4U

//
// Capacity reserved for BOOTLOG.TXT: 64 clusters * 2048 B = 128 KiB.  Clusters
// are handed out lazily as the file grows, so the chain on disk always matches
// the file size (no orphaned/pre-allocated clusters for chkdsk to complain
// about).  When the cap is reached, appends are dropped instead of wrapping.
//
#define FAT_MAX_FILE_CLUSTERS 64U
#define FAT_MAX_FILE_BYTES    ((UINT32)FAT_MAX_FILE_CLUSTERS * FAT_SEC_PER_CLUS * LOGDISK_BLOCK)

//
// Fixed creation timestamp so the on-disk image is deterministic:
// 2026-10-22 00:00:00 (FAT date: (2026-1980)<<9 | 10<<5 | 22).
//
#define FAT_FIXED_TIME      0x0000U
#define FAT_FIXED_DATE      0x5D56U

#define FAT_ATTR_VOLUME_ID  0x08U
#define FAT_ATTR_ARCHIVE    0x20U
#define FAT_EOC12           0x0FFFU
#define FAT_EOC16           0xFFFFU

STATIC UINT8              *mDisk       = NULL;
STATIC EFI_BLOCK_IO_MEDIA  mMedia;
STATIC UINT32              mMediaId     = 1;

/* ---- computed geometry --------------------------------------------------- */
STATIC UINT32   mFatSecs      = 0;   /* sectors occupied by the single FAT      */
STATIC UINT32   mRootSecs     = 0;   /* sectors occupied by the root directory  */
STATIC UINT32   mRootLba      = 0;   /* first root-directory sector             */
STATIC UINT32   mDataLba      = 0;   /* first data sector (cluster #2)          */
STATIC UINT32   mClusterCount = 0;   /* number of data clusters                 */
STATIC UINT8    mFatBits      = 0;   /* 12 or 16, decided by mClusterCount      */
STATIC BOOLEAN  mFatReady     = FALSE;

/* ---- BOOTLOG.TXT state --------------------------------------------------- */
STATIC UINT32   mFileBytes     = 0;   /* logical file size                      */
STATIC UINT32   mAllocClusters = 0;   /* clusters currently linked to the file  */
STATIC BOOLEAN  mFileFull      = FALSE;

#pragma pack(1)
typedef struct {
  UINT8   Name[11];       /* 8.3, space padded                                    */
  UINT8   Attr;           /* 0x20 = archive                                       */
  UINT8   NtRes;
  UINT8   CrtTimeTenth;
  UINT16  CrtTime;
  UINT16  CrtDate;
  UINT16  LstAccDate;
  UINT16  FstClusHI;      /* 0 for FAT12/16                                       */
  UINT16  WrtTime;
  UINT16  WrtDate;
  UINT16  FstClusLO;
  UINT32  FileSize;
} FAT_DIR_ENTRY;
#pragma pack()

#define FAT_ROOT_BASE     ((FAT_DIR_ENTRY *)(mDisk + ((UINTN)mRootLba * LOGDISK_BLOCK)))
#define FAT_LABEL_ENTRY   (&FAT_ROOT_BASE[0])   /* attr 0x08, no data            */
#define FAT_FILE_ENTRY    (&FAT_ROOT_BASE[1])   /* BOOTLOG.TXT                   */
#define FAT_FILE_DATA     (mDisk + ((UINTN)mDataLba * LOGDISK_BLOCK))

/* ---- boot sector helpers (endian neutral, no packed struct needed) -------- */
STATIC
VOID
FatPut16 (
  IN UINT8   *Dst,
  IN UINT16   Val
  )
{
  Dst[0] = (UINT8)(Val & 0xFF);
  Dst[1] = (UINT8)((Val >> 8) & 0xFF);
}

STATIC
VOID
FatPut32 (
  IN UINT8   *Dst,
  IN UINT32   Val
  )
{
  Dst[0] = (UINT8)(Val & 0xFF);
  Dst[1] = (UINT8)((Val >> 8) & 0xFF);
  Dst[2] = (UINT8)((Val >> 16) & 0xFF);
  Dst[3] = (UINT8)((Val >> 24) & 0xFF);
}

STATIC
VOID
FatPutStr (
  IN UINT8         *Dst,
  IN CONST CHAR8   *Src,
  IN UINTN          Len
  )
{
  ZeroMem (Dst, Len);
  CopyMem (Dst, Src, AsciiStrLen (Src) < Len ? AsciiStrLen (Src) : Len);
}

/* ---- FAT entry access (12-bit packed or 16-bit) -------------------------- */
STATIC
UINT32
FatGetEntry (
  IN UINT32  Cluster
  )
{
  UINT8  *Fat = mDisk + ((UINTN)FAT_RSVD_SEC * LOGDISK_BLOCK);

  if (mFatBits == 12) {
    UINTN  Off = Cluster + (Cluster >> 1);
    UINT16 Raw = (UINT16)(Fat[Off] | ((UINT16)Fat[Off + 1] << 8));
    return (Cluster & 1) ? (UINT32)(Raw >> 4) : (UINT32)(Raw & 0x0FFF);
  } else {
    return (UINT32)(Fat[(UINTN)Cluster * 2] | ((UINT16)Fat[(UINTN)Cluster * 2 + 1] << 8));
  }
}

STATIC
VOID
FatSetEntry (
  IN UINT32  Cluster,
  IN UINT32  Value
  )
{
  UINT8  *Fat = mDisk + ((UINTN)FAT_RSVD_SEC * LOGDISK_BLOCK);

  if (mFatBits == 12) {
    UINTN   Off = Cluster + (Cluster >> 1);
    UINT16  Raw = (UINT16)(Fat[Off] | ((UINT16)Fat[Off + 1] << 8));

    Value &= 0x0FFF;
    if (Cluster & 1) {
      Raw = (UINT16)((Raw & 0x000F) | ((UINT16)Value << 4));
    } else {
      Raw = (UINT16)((Raw & 0xF000) | (UINT16)Value);
    }
    Fat[Off]     = (UINT8)(Raw & 0xFF);
    Fat[Off + 1] = (UINT8)(Raw >> 8);
  } else {
    Fat[(UINTN)Cluster * 2]     = (UINT8)(Value & 0xFF);
    Fat[(UINTN)Cluster * 2 + 1] = (UINT8)((Value >> 8) & 0xFF);
  }
}

/* ---- geometry ------------------------------------------------------------ */
STATIC
EFI_STATUS
FatComputeGeometry (
  VOID
  )
{
  UINT32  FatSecs;
  UINT32  DataSecs;
  UINT32  Clusters;

  mRootSecs = (FAT_ROOT_ENTRIES * sizeof (FAT_DIR_ENTRY) + LOGDISK_BLOCK - 1) / LOGDISK_BLOCK;

  for (FatSecs = 1; FatSecs <= 16; FatSecs++) {
    DataSecs = LOGDISK_BLOCKS - FAT_RSVD_SEC - FAT_NUM_FATS * FatSecs - mRootSecs;
    if (DataSecs <= 0) {
      continue;
    }
    Clusters = DataSecs / FAT_SEC_PER_CLUS;
    if (Clusters <= 4084) {
      /* FAT12: 1.5 bytes per entry, rounded up to whole sectors. */
      if (((UINT64)(Clusters + 2) * 3 + 1) / 2 <= (UINT64)FatSecs * LOGDISK_BLOCK) {
        break;
      }
    } else {
      /* FAT16: 2 bytes per entry. */
      if ((UINT64)(Clusters + 2) * 2 <= (UINT64)FatSecs * LOGDISK_BLOCK) {
        break;
      }
    }
  }

  if (FatSecs > 16) {
    return EFI_UNSUPPORTED;
  }

  mFatSecs      = FatSecs;
  mRootLba      = FAT_RSVD_SEC + FAT_NUM_FATS * mFatSecs;
  mDataLba      = mRootLba + mRootSecs;
  mClusterCount = (LOGDISK_BLOCKS - mDataLba) / FAT_SEC_PER_CLUS;
  mFatBits      = (mClusterCount < 4085) ? 12 : 16;
  return EFI_SUCCESS;
}

/* ---- format -------------------------------------------------------------- */
STATIC
VOID
FatWriteBootSector (
  VOID
  )
{
  UINT8  *Bs = mDisk;

  /* Jump + OEM name */
  Bs[0] = 0xEB; Bs[1] = 0x3C; Bs[2] = 0x90;
  FatPutStr (Bs + 0x03, "VERMEER ", 8);

  FatPut16 (Bs + 0x0B, LOGDISK_BLOCK);                       /* BPB_BytsPerSec    */
  Bs[0x0D] = (UINT8)FAT_SEC_PER_CLUS;                        /* BPB_SecPerClus    */
  FatPut16 (Bs + 0x0E, FAT_RSVD_SEC);                        /* BPB_RsvdSecCnt    */
  Bs[0x10] = (UINT8)FAT_NUM_FATS;                            /* BPB_NumFATs       */
  FatPut16 (Bs + 0x11, FAT_ROOT_ENTRIES);                    /* BPB_RootEntCnt    */
  FatPut16 (Bs + 0x13, (UINT16)LOGDISK_BLOCKS);              /* BPB_TotSec16      */
  Bs[0x15] = 0xF8;                                           /* BPB_Media         */
  FatPut16 (Bs + 0x16, (UINT16)mFatSecs);                    /* BPB_FATSz16       */
  FatPut16 (Bs + 0x18, 32);                                  /* BPB_SecPerTrk     */
  FatPut16 (Bs + 0x1A, 64);                                  /* BPB_NumHeads      */
  FatPut32 (Bs + 0x1C, 0);                                   /* BPB_HiddSec       */
  FatPut32 (Bs + 0x20, 0);                                   /* BPB_TotSec32      */
  Bs[0x24] = 0x80;                                           /* BS_DrvNum         */
  Bs[0x25] = 0x00;                                           /* BS_Reserved1      */
  Bs[0x26] = 0x29;                                           /* BS_BootSig        */
  FatPut32 (Bs + 0x27, 0x4B37304CU);                         /* BS_VolID          */
  FatPutStr (Bs + 0x2B, "K70 LOGDISK", 11);                  /* BS_VolLab         */
  FatPutStr (Bs + 0x36, (mFatBits == 12) ? "FAT12   " : "FAT16   ", 8);
  FatPut16 (Bs + 0xFE, 0xAA55);                              /* signature         */

  /* Not bootable: cli / hlt / jmp $-1, keeps a PC from executing garbage. */
  Bs[0x3E] = 0xFA;
  Bs[0x3F] = 0xF4;
  Bs[0x40] = 0xEB;
  Bs[0x41] = 0xFD;
}

/**
  Make BOOTLOG.TXT's cluster chain long enough to hold the current file size
  plus ExtraBytes more.

  Clusters are handed out contiguously from #2 upward and every newly linked
  cluster is marked EOC, so the on-disk chain length is always exactly
  ceil(file size / cluster size) - i.e. no pre-allocated tail for fsck/chkdsk
  to report as orphaned.  Returns FALSE when the file would pass the cap.

  @param[in] ExtraBytes  Bytes about to be appended.
  @retval TRUE   chain is long enough, caller may copy the data.
  @retval FALSE  file is full, caller must drop the line.
**/
STATIC
BOOLEAN
FatGrowFileChain (
  IN UINT32  ExtraBytes
  )
{
  UINT32  ClusterBytes = (UINT32)FAT_SEC_PER_CLUS * LOGDISK_BLOCK;
  UINT32  Need;
  UINT32  Cluster;

  Need = (mFileBytes + ExtraBytes + ClusterBytes - 1) / ClusterBytes;
  if (Need > FAT_MAX_FILE_CLUSTERS) {
    return FALSE;
  }

  while (mAllocClusters < Need) {
    Cluster = 2U + mAllocClusters;
    if (Cluster > mClusterCount + 1U) {
      return FALSE;
    }
    FatSetEntry (Cluster, (mFatBits == 12) ? FAT_EOC12 : FAT_EOC16);
    if (mAllocClusters == 0) {
      FatPut16 ((UINT8 *)&FAT_FILE_ENTRY->FstClusLO, (UINT16)Cluster);
    } else {
      FatSetEntry (Cluster - 1U, Cluster);
    }
    mAllocClusters++;
  }

  return TRUE;
}

STATIC
VOID
FatUpdateFileSize (
  VOID
  )
{
  FAT_FILE_ENTRY->FileSize = mFileBytes;
  FAT_FILE_ENTRY->WrtTime  = FAT_FIXED_TIME;
  FAT_FILE_ENTRY->WrtDate  = FAT_FIXED_DATE;
}

STATIC
EFI_STATUS
FatFormatVolume (
  VOID
  )
{
  EFI_STATUS      Status;
  FAT_DIR_ENTRY  *Dir;

  Status = FatComputeGeometry ();
  if (EFI_ERROR (Status)) {
    return Status;
  }
  DEBUG ((
    DEBUG_ERROR,
    "[FAT16] geometry: media=%d B, spc=%d, rsvd=%d, fat=%d sec, root=%d sec, data_lba=%d, clusters=%d -> FAT%d\n",
    (UINT32)LOGDISK_BYTES, FAT_SEC_PER_CLUS, FAT_RSVD_SEC, mFatSecs, mRootSecs,
    mDataLba, mClusterCount, mFatBits
    ));

  if (FAT_MAX_FILE_CLUSTERS + 2U > mClusterCount) {
    return EFI_VOLUME_FULL;
  }

  ZeroMem (mDisk, LOGDISK_BYTES);

  /* FAT[0]/FAT[1]: media descriptor + clean-shutdown / EOC marker. */
  FatSetEntry (0, (mFatBits == 12) ? 0x0FF8U : 0xFFF8U);
  FatSetEntry (1, (mFatBits == 12) ? FAT_EOC12 : FAT_EOC16);
  /* No clusters are linked to BOOTLOG.TXT yet: the chain grows on demand. */

  /* root[0] = volume label.  Required: BPB_VolLab is not "NO NAME", and
     fsck.fat/Windows expect the matching 0x08 entry in the root directory. */
  Dir = FAT_LABEL_ENTRY;
  FatPutStr (Dir->Name, "K70 LOGDISK", 11);
  Dir->Attr = FAT_ATTR_VOLUME_ID;

  /* root[1] = BOOTLOG.TXT.  Empty file; first cluster is assigned on the first
     append, so a volume where nothing was ever logged is still consistent. */
  Dir = FAT_FILE_ENTRY;
  FatPutStr (Dir->Name, "BOOTLOG TXT", 11);
  Dir->Attr         = FAT_ATTR_ARCHIVE;
  Dir->NtRes        = 0;
  Dir->CrtTimeTenth = 0;
  FatPut16 ((UINT8 *)&Dir->CrtTime, FAT_FIXED_TIME);
  FatPut16 ((UINT8 *)&Dir->CrtDate, FAT_FIXED_DATE);
  FatPut16 ((UINT8 *)&Dir->LstAccDate, FAT_FIXED_DATE);
  FatPut16 ((UINT8 *)&Dir->FstClusHI, 0);
  FatPut16 ((UINT8 *)&Dir->FstClusLO, 0);
  FatUpdateFileSize ();

  FatWriteBootSector ();

  mFileBytes     = 0;
  mAllocClusters = 0;
  mFileFull      = FALSE;
  mFatReady      = TRUE;
  return EFI_SUCCESS;
}

/* ---- public-in-driver append API ----------------------------------------- */
/**
  Append one text line to BOOTLOG.TXT.

  The cluster chain grows lazily as the file gets longer, so every call ends up
  as a memcpy into the data area plus a directory-size update and, when a
  cluster boundary is crossed, one more FAT entry.  When the 128 KiB cap is
  exhausted the line is dropped and mFileFull is latched (we stop instead of
  wrapping, so the first lines of the boot are never overwritten).

  @param[in] Line  NUL-terminated ASCII string, usually ending in "\r\n".
**/
STATIC
VOID
FatAppendLogLine (
  IN CONST CHAR8  *Line
  )
{
  UINTN  Len;

  if (!mFatReady || (Line == NULL)) {
    return;
  }

  Len = AsciiStrLen (Line);
  if ((Len == 0) || mFileFull) {
    return;
  }

  if (mFileBytes + Len > FAT_MAX_FILE_BYTES) {
    mFileFull = TRUE;
    return;
  }

  if (!FatGrowFileChain ((UINT32)Len)) {
    mFileFull = TRUE;
    return;
  }

  CopyMem (FAT_FILE_DATA + mFileBytes, Line, Len);
  mFileBytes += (UINT32)Len;
  FatUpdateFileSize ();
}

/* ---- read-back self check ------------------------------------------------ */
STATIC
VOID
FatSelfCheck (
  VOID
  )
{
  FAT_DIR_ENTRY  *Dir;
  FAT_DIR_ENTRY  *Lab;
  UINT16          Sig;
  CHAR8           Name[12];
  CHAR8           VolLab[12];
  CHAR8           Head[20];
  UINTN           Len;
  UINT32          Cur;
  UINT32          Next;
  UINT32          Walked;
  BOOLEAN         ChainOk;

  if (!mFatReady) {
    DEBUG ((DEBUG_ERROR, "[FAT] selfcheck: volume not ready\n"));
    return;
  }

  Sig = (UINT16)(mDisk[510] | ((UINT16)mDisk[511] << 8));
  Lab = FAT_LABEL_ENTRY;
  Dir = FAT_FILE_ENTRY;

  CopyMem (Name, Dir->Name, 11);
  Name[11] = '\0';
  CopyMem (VolLab, Lab->Name, 11);
  VolLab[11] = '\0';

  Len = (Dir->FileSize < 19) ? (UINTN)Dir->FileSize : 19;
  CopyMem (Head, FAT_FILE_DATA, Len);
  Head[Len] = '\0';

  /*
    Walk BOOTLOG.TXT's FAT chain exactly the way a FAT driver would: follow the
    entries from the first cluster, check every hop is the next contiguous
    cluster and that the chain ends in EOC after mAllocClusters hops.  This
    exercises the real on-disk metadata, not the in-memory bookkeeping.
  */
  ChainOk = TRUE;
  Walked  = 0;
  Cur     = (UINT32)Dir->FstClusLO | ((UINT32)Dir->FstClusHI << 16);
  while ((mAllocClusters != 0) && (Walked < mAllocClusters)) {
    Next = FatGetEntry (Cur);
    Walked++;
    if (Next == ((mFatBits == 12) ? FAT_EOC12 : FAT_EOC16)) {
      break;
    }
    if (Next != Cur + 1U) {
      ChainOk = FALSE;
      break;
    }
    Cur = Next;
  }
  if ((mAllocClusters != 0) && (Walked != mAllocClusters)) {
    ChainOk = FALSE;
  }

  DEBUG ((
    DEBUG_ERROR,
    "[FAT] selfcheck: sig=0x%04x vol=\"%a\"(attr=%d) file=\"%a\"(attr=%d) size=%d clusters=%d chain_split=%d(%s) head=\"%a\"\n",
    Sig,
    VolLab,
    Lab->Attr,
    Name,
    Dir->Attr,
    Dir->FileSize,
    mAllocClusters,
    ChainOk ? 1 : 0,
    (mFatBits == 12) ? "FAT12" : "FAT16",
    Head
    ));
}

/* ======================================================================== */
/* EFI_BLOCK_IO_PROTOCOL - behaviour deliberately unchanged from keys122.   */
/* ======================================================================== */

STATIC
EFI_STATUS
EFIAPI
LogDiskReset (
  IN EFI_BLOCK_IO_PROTOCOL  *This,
  IN BOOLEAN                 ExtendedVerification
  )
{
  return EFI_SUCCESS;
}

STATIC
EFI_STATUS
EFIAPI
LogDiskRead (
  IN  EFI_BLOCK_IO_PROTOCOL  *This,
  IN  UINT32                  MediaId,
  IN  EFI_LBA                 Lba,
  IN  UINTN                   BufferSize,
  OUT VOID                   *Buffer
  )
{
  if (Buffer == NULL) {
    return EFI_INVALID_PARAMETER;
  }

  if (MediaId != mMedia.MediaId) {
    return EFI_MEDIA_CHANGED;
  }

  if ((Lba + (BufferSize / LOGDISK_BLOCK)) > (UINT64)mMedia.LastBlock + 1) {
    return EFI_INVALID_PARAMETER;
  }

  CopyMem (Buffer, mDisk + (UINTN)Lba * LOGDISK_BLOCK, BufferSize);
  return EFI_SUCCESS;
}

STATIC
EFI_STATUS
EFIAPI
LogDiskWrite (
  IN EFI_BLOCK_IO_PROTOCOL  *This,
  IN UINT32                  MediaId,
  IN EFI_LBA                 Lba,
  IN UINTN                   BufferSize,
  IN VOID                   *Buffer
  )
{
  if (Buffer == NULL) {
    return EFI_INVALID_PARAMETER;
  }

  if (MediaId != mMedia.MediaId) {
    return EFI_MEDIA_CHANGED;
  }

  if ((Lba + (BufferSize / LOGDISK_BLOCK)) > (UINT64)mMedia.LastBlock + 1) {
    return EFI_INVALID_PARAMETER;
  }

  CopyMem (mDisk + (UINTN)Lba * LOGDISK_BLOCK, Buffer, BufferSize);
  return EFI_SUCCESS;
}

STATIC
EFI_STATUS
EFIAPI
LogDiskFlush (
  IN EFI_BLOCK_IO_PROTOCOL  *This
  )
{
  return EFI_SUCCESS;
}

STATIC EFI_BLOCK_IO_PROTOCOL mBlockIo = {
  EFI_BLOCK_IO_PROTOCOL_REVISION,
  &mMedia,
  LogDiskReset,
  LogDiskRead,
  LogDiskWrite,
  LogDiskFlush
};

//
// Minimal vendor device path node so that consumers that require a
// DevicePath protocol on the handle are satisfied.
//
#pragma pack(1)
typedef struct {
  VENDOR_DEVICE_PATH        Vendor;
  EFI_DEVICE_PATH_PROTOCOL  End;
} LOGDISK_DEVICE_PATH;
#pragma pack()

STATIC LOGDISK_DEVICE_PATH mDevicePath = {
  { { HARDWARE_DEVICE_PATH, HW_VENDOR_DP, { sizeof (VENDOR_DEVICE_PATH), 0 } },
    { 0x6D31A8C2, 0x5F47, 0x4E39, { 0xB2, 0xA1, 0x9C, 0x4E, 0x7D, 0x5A, 0x1B, 0x64 } } },
  { END_DEVICE_PATH_TYPE, END_ENTIRE_DEVICE_PATH_SUBTYPE, { sizeof (EFI_DEVICE_PATH_PROTOCOL), 0 } }
};

EFI_STATUS
EFIAPI
VermeerLogDiskDxeEntry (
  IN EFI_HANDLE        ImageHandle,
  IN EFI_SYSTEM_TABLE  *SystemTable
  );

EFI_STATUS
EFIAPI
VermeerLogDiskDxeEntry (
  IN EFI_HANDLE        ImageHandle,
  IN EFI_SYSTEM_TABLE  *SystemTable
  )
{
  EFI_STATUS  Status;
  EFI_HANDLE  Handle;

  mDisk = AllocateZeroPool (LOGDISK_BYTES);
  if (mDisk == NULL) {
    DEBUG ((DEBUG_ERROR, "[LOGDISK] out of memory\n"));
    return EFI_OUT_OF_RESOURCES;
  }

  Status = FatFormatVolume ();
  if (EFI_ERROR (Status)) {
    DEBUG ((DEBUG_ERROR, "[FAT16] format failed: %r\n", Status));
    return Status;
  }

  DEBUG ((DEBUG_ERROR, "[FAT16] volume ready, root entries=%d\n", FAT_ROOT_ENTRIES));

  FatAppendLogLine ("VERMEER-UEFI LOGDISK\r\n");
  FatAppendLogLine ("[FAT16] volume ready, root entries=32\r\n");
  FatAppendLogLine ("BOOTLOG.TXT is written by VermeerLogDiskDxe\r\n");
  FatSelfCheck ();

  ZeroMem (&mMedia, sizeof (mMedia));
  mMedia.MediaId          = mMediaId;
  mMedia.RemovableMedia   = TRUE;
  mMedia.MediaPresent     = TRUE;
  mMedia.LogicalPartition = FALSE;
  mMedia.ReadOnly         = FALSE;
  mMedia.WriteCaching     = FALSE;
  mMedia.BlockSize        = LOGDISK_BLOCK;
  mMedia.IoAlign          = 0;
  mMedia.LastBlock        = LOGDISK_BLOCKS - 1;

  Handle = NULL;
  Status = gBS->InstallMultipleProtocolInterfaces (
                  &Handle,
                  &gEfiBlockIoProtocolGuid,
                  &mBlockIo,
                  &gEfiDevicePathProtocolGuid,
                  &mDevicePath,
                  NULL
                  );
  DEBUG ((DEBUG_ERROR, "[LOGDISK] install -> %r, %d blocks of %d bytes\n",
          Status, LOGDISK_BLOCKS, LOGDISK_BLOCK));

  if (VERMEER_USB_DIAG) {
    EFI_STATUS  DiagStatus;

    //
    // Event-driven evidence: if UsbfnDwc3Dxe ever installs gEfiUsbFunctionIo,
    // its Start() ran successfully (this is the only hard proof).  Subscribing
    // is harmless even when the protocol never appears.
    //
    DiagStatus = gBS->CreateEvent (
                        EVT_NOTIFY_SIGNAL,
                        TPL_CALLBACK,
                        UsbFnIoNotify,
                        NULL,
                        &mUsbFnIoEvent
                        );
    if (!EFI_ERROR (DiagStatus)) {
      DiagStatus = gBS->RegisterProtocolNotify (
                          (EFI_GUID *)&mUsbFnIoGuid,
                          mUsbFnIoEvent,
                          &mUsbFnIoReg
                          );
      DEBUG ((DEBUG_ERROR, "[USBDIAG] UsbFnIo notify register -> %r\n", DiagStatus));
    }

    //
    // Deferred snapshot: a relative timer at TPL_CALLBACK fires once BDS starts
    // pumping events (2 s after dispatch ends), i.e. after every driver in the
    // APRIORI list has been loaded and ConnectController has run.
    //
    DiagStatus = gBS->CreateEvent (
                        EVT_TIMER,
                        TPL_CALLBACK,
                        UsbDiagTimerCallback,
                        NULL,
                        &mUsbDiagEvent
                        );
    if (!EFI_ERROR (DiagStatus)) {
      gBS->SetTimer (mUsbDiagEvent, TimerRelative, 20000000ULL); /* 2 s */
    }

    DEBUG ((DEBUG_ERROR, "[USBDIAG] probe timer arm -> %r (2 s)\n", DiagStatus));
  }

  return Status;
}
