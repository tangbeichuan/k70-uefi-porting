/** @file
  VermeerDtDumpDxe ¡ª print (a slice of) the device tree this firmware actually received.

  Dispatched from APRIORI right after PcdDxe, i.e. BEFORE any vendor driver, so the output is
  on screen no matter which vendor module asserts later.

  Gated behind VERMEER_DTDUMP in vermeer.dsc / vermeer.fdf (default 0).
**/
#include <Uefi.h>

#include <Library/BaseLib.h>
#include <Library/BaseMemoryLib.h>
#include <Library/DebugLib.h>
#include <Library/HobLib.h>
#include <Library/MemoryAllocationLib.h>
#include <Library/PrintLib.h>
#include <Library/UefiBootServicesTableLib.h>
#include <Library/UefiDriverEntryPoint.h>

#define DTDUMP_TAG        "[DTDUMP] "
#define DTDUMP_MAXPATH    160
#define DTDUMP_MAXPRINT   140
#define DTDUMP_MAXCT      24

// gFdtTableGuid / EFI_DTB_TABLE_GUID, defined locally so the module needs MdePkg only.
STATIC CONST EFI_GUID  mFdtTableGuid = {
  0xB1B621D5, 0xF19C, 0x41A5, { 0x83, 0x0B, 0xD9, 0x15, 0x2C, 0x69, 0xAA, 0xE0 }
};

// gEfiDtbExtensionHobGuid (QcomPkg.dec:17) ¡ª built by PlatformPeiLib from XBL's HOB function.
STATIC CONST EFI_GUID  mDtbExtnHobGuid = {
  0x3A06E1E8, 0x61F6, 0x11EB, { 0xBB, 0xED, 0x4B, 0x47, 0x6E, 0x2F, 0xF6, 0xA7 }
};

// DTBExtn protocol, as installed by EnvDxe (recovered from EnvDxe.efi @0x2bf0:
// gBS->InstallMultipleProtocolInterfaces (InstallMultipleProtocolInterfaces, &guid, &ifc)).
STATIC CONST EFI_GUID  mDtbExtnProtoGuid = {
  0x0389B776, 0x625F, 0x11EB, { 0x83, 0xBE, 0xC7, 0x41, 0xA9, 0x13, 0xDE, 0x34 }
};

STATIC UINT64     mDtbExtnAddr   = 0;
// keys35: payloads of the Info Blk / Shim / Scheduler interface HOBs.  These are the only
// numbers XBL actually handed PEI, so they are the last honest lead to the live device tree.
STATIC UINT64     mInfoBlkAddr    = 0;
STATIC UINT64     mShimAddr       = 0;
STATIC UINT64     mSchedAddr      = 0;

STATIC
VOID
DumpHobPayloadPages (
  VOID
  );
// keys30: 1 = skip the legacy probe stages (kept referenced so no unused-function warnings).
STATIC volatile UINTN  mLegacyProbe = 0;

STATIC
UINT32
RdBe32 (
  IN CONST UINT8  *P
  )
{
  return ((UINT32)P[0] << 24) | ((UINT32)P[1] << 16) | ((UINT32)P[2] << 8) | (UINT32)P[3];
}

STATIC
BOOLEAN
IsWantedProp (
  IN CONST CHAR8  *Name
  )
{
  if (AsciiStrCmp (Name, "init_speed_params") == 0)  { return TRUE; }
  if (AsciiStrCmp (Name, "perf_speed_params") == 0)  { return TRUE; }
  if (AsciiStrCmp (Name, "timeout_values") == 0)     { return TRUE; }
  if (AsciiStrCmp (Name, "ufs0_vcc") == 0)           { return TRUE; }
  if (AsciiStrCmp (Name, "ufs0_vccq") == 0)          { return TRUE; }
  if (AsciiStrCmp (Name, "ufs0_vdda") == 0)          { return TRUE; }
  if (AsciiStrCmp (Name, "ufs0_vdda_core") == 0)     { return TRUE; }
  return FALSE;
}

STATIC
VOID
WalkFdt (
  IN CONST UINT8  *Fdt,
  IN UINT32       TotalSize
  )
{
  UINT32        OffStruct;
  UINT32        OffStrings;
  UINT32        SizeStruct;
  UINT32        SizeStrings;
  CONST UINT8   *P;
  CONST UINT8   *EndP;
  CONST CHAR8   *StrBlk;
  CHAR8         Path[DTDUMP_MAXPATH];
  CHAR8         NewPath[DTDUMP_MAXPATH];
  UINTN         Depth;
  UINTN         Printed;
  UINTN         NodeCount;
  UINTN         PropCount;
  BOOLEAN       Ufs0Seen;
  BOOLEAN       SocSeen;
  BOOLEAN       PmicClientSeen;

  OffStruct    = RdBe32 (Fdt + 8);
  OffStrings   = RdBe32 (Fdt + 12);
  SizeStruct   = RdBe32 (Fdt + 36);
  SizeStrings  = RdBe32 (Fdt + 32);
  if ((OffStruct == 0) || (OffStruct >= TotalSize) || (SizeStruct == 0)) {
    DEBUG ((DEBUG_ERROR, DTDUMP_TAG "bad fdt header (off_struct=0x%x)\n", OffStruct));
    return;
  }
  if ((OffStrings == 0) || (OffStrings >= TotalSize)) {
    DEBUG ((DEBUG_ERROR, DTDUMP_TAG "bad fdt header (off_strings=0x%x)\n", OffStrings));
    return;
  }
  if ((UINT64)OffStruct + SizeStruct > (UINT64)TotalSize) {
    SizeStruct = TotalSize - OffStruct;
  }
  if ((UINT64)OffStrings + SizeStrings > (UINT64)TotalSize) {
    SizeStrings = TotalSize - OffStrings;
  }

  StrBlk = (CONST CHAR8 *)(Fdt + OffStrings);
  DEBUG ((DEBUG_ERROR, DTDUMP_TAG "hdr magic=0x%x total=0x%x ver=%d struct@0x%x(+0x%x) strings@0x%x(+0x%x)\n",
          RdBe32 (Fdt), TotalSize, RdBe32 (Fdt + 20), OffStruct, SizeStruct, OffStrings, SizeStrings));

  P            = Fdt + OffStruct;
  EndP         = Fdt + OffStruct + SizeStruct;
  Path[0]      = '\0';
  Depth        = 0;
  Printed      = 0;
  NodeCount    = 0;
  PropCount    = 0;
  Ufs0Seen     = FALSE;
  SocSeen      = FALSE;
  PmicClientSeen = FALSE;

  while ((P + 4) <= EndP) {
    UINT32  Token = RdBe32 (P);

    P += 4;
    if (Token == 1) {                     // FDT_BEGIN_NODE
      CONST CHAR8  *Name = (CONST CHAR8 *)P;
      UINTN        Len   = AsciiStrLen (Name);

      P += ((Len + 4) & ~((UINTN)3));
      if (Depth == 0) {
        AsciiStrCpyS (NewPath, sizeof (NewPath), "/");
      } else {
        if (AsciiStrLen (Path) + Len + 2 <= sizeof (NewPath)) {
          AsciiStrCpyS (NewPath, sizeof (NewPath), Path);
          if (NewPath[AsciiStrLen (NewPath) - 1] != '/') {
            AsciiStrCatS (NewPath, sizeof (NewPath), "/");
          }
          AsciiStrCatS (NewPath, sizeof (NewPath), Name);
        } else {
          AsciiStrCpyS (NewPath, sizeof (NewPath), Path);
        }
      }
      AsciiStrCpyS (Path, sizeof (Path), NewPath);
      Depth++;
      NodeCount++;
      if (AsciiStrCmp (Path, "/soc/ufs0") == 0) {
        Ufs0Seen = TRUE;
      }
      if (AsciiStrCmp (Path, "/soc") == 0) {
        SocSeen = TRUE;
      }
      if (AsciiStrCmp (Path, "/pmic/client") == 0) {
        PmicClientSeen = TRUE;
      }
      // print root, /soc and /soc/<child>; everything deeper is only reported for UFS nodes
      if ((Depth <= 2) && (Printed < DTDUMP_MAXPRINT)) {
        DEBUG ((DEBUG_ERROR, DTDUMP_TAG "node %a\n", Path));
        Printed++;
      }
    } else if (Token == 2) {              // FDT_END_NODE
      if (Depth > 0) {
        Depth--;
        // rebuild the parent path by truncating at the last '/'
        if (Depth == 0) {
          Path[0] = '\0';
          AsciiStrCpyS (Path, sizeof (Path), "/");
        } else {
          CHAR8  *Slash = AsciiStrStr (Path, "/");  // keep simple: walk back last '/'
          CHAR8  *Last  = NULL;
          CHAR8  *Q;
          for (Q = Path; *Q != '\0'; Q++) {
            if (*Q == '/') {
              Last = Q;
            }
          }
          (VOID)Slash;
          if ((Last != NULL) && (Last != Path)) {
            *Last = '\0';
          } else {
            AsciiStrCpyS (Path, sizeof (Path), "/");
          }
        }
      }
    } else if (Token == 3) {              // FDT_PROP
      UINT32  Len;
      UINT32  NameOff;
      CONST CHAR8  *PropName;

      if ((P + 8) > EndP) {
        break;
      }
      Len     = RdBe32 (P);
      NameOff = RdBe32 (P + 4);
      P      += 8;
      PropName = (CONST CHAR8 *)((CONST UINT8 *)StrBlk + NameOff);
      PropCount++;
      if ((Len < 0x10000) && (P + Len <= EndP)) {
        if (IsWantedProp (PropName)) {
          DEBUG ((DEBUG_ERROR, DTDUMP_TAG "PROP %a %a len=%d\n", Path, PropName, Len));
        }
      }
      P += ((Len + 3) & ~((UINT32)3));
    } else if (Token == 4) {              // FDT_NOP
      continue;
    } else if (Token == 9) {              // FDT_END
      break;
    } else {
      DEBUG ((DEBUG_ERROR, DTDUMP_TAG "unexpected token 0x%x at 0x%x\n", Token,
              (UINT32)((UINTN)P - (UINTN)Fdt - 4)));
      break;
    }
  }

  DEBUG ((DEBUG_ERROR, DTDUMP_TAG "walk done: nodes=%d props=%d printed=%d\n",
          NodeCount, PropCount, Printed));
  DEBUG ((DEBUG_ERROR, DTDUMP_TAG "check /soc=%a /soc/ufs0=%a /pmic/client=%a\n",
          SocSeen ? "yes" : "NO", Ufs0Seen ? "yes" : "NO", PmicClientSeen ? "yes" : "NO"));
}

STATIC
VOID
DumpConfigTables (
  VOID
  )
{
  UINTN  Index;
  UINTN  Shown;
  BOOLEAN  FdtFound;

  FdtFound = FALSE;
  Shown    = 0;
  if (gST->NumberOfTableEntries == 0) {
    DEBUG ((DEBUG_ERROR, DTDUMP_TAG "cfgtable: none\n"));
    return;
  }
  DEBUG ((DEBUG_ERROR, DTDUMP_TAG "cfgtable count=%d\n", gST->NumberOfTableEntries));
  for (Index = 0; (Index < gST->NumberOfTableEntries) && (Shown < DTDUMP_MAXCT); Index++) {
    EFI_CONFIGURATION_TABLE  *Entry = &gST->ConfigurationTable[Index];
    if (CompareGuid (&Entry->VendorGuid, &mFdtTableGuid)) {
      FdtFound = TRUE;
      DEBUG ((DEBUG_ERROR, DTDUMP_TAG "cfgtable[%d] FDT addr=0x%lx\n", Index, (UINT64)(UINTN)Entry->VendorTable));
      Shown++;
    }
  }
  if (!FdtFound) {
    DEBUG ((DEBUG_ERROR, DTDUMP_TAG "no FDT table installed\n"));
  }
}

STATIC
VOID
DumpHobWords (
  IN EFI_HOB_GUID_TYPE  *GuidHob,
  IN VOID               *Hob
  )
{
  UINT64       *W;
  UINTN        Count;
  UINTN        Index;
  CONST UINT8  *P;

  Count = (GET_HOB_LENGTH (Hob) - sizeof (EFI_HOB_GUID_TYPE)) / sizeof (UINT64);
  if (Count > 4) {
    Count = 4;
  }
  W = (UINT64 *)GET_GUID_HOB_DATA (Hob);
  DEBUG ((DEBUG_ERROR, DTDUMP_TAG "  hob %g len=0x%x w=", &GuidHob->Name, GET_HOB_LENGTH (Hob)));
  for (Index = 0; Index < Count; Index++) {
    DEBUG ((DEBUG_ERROR, "%lx ", W[Index]));
  }
  DEBUG ((DEBUG_ERROR, "\n"));
  for (Index = 0; Index < Count; Index++) {
    if ((W[Index] >= 0xA8000000ULL) && (W[Index] < 0xB8000000ULL) && ((W[Index] & 3) == 0)) {
      P = (CONST UINT8 *)(UINTN)W[Index];
      DEBUG ((DEBUG_ERROR, DTDUMP_TAG "   w[%d]=0x%lx -> magic=%08x%s\n",
              Index, W[Index], RdBe32 (P),
              (RdBe32 (P) == 0xD00DFEED) ? " FDT!" : ""));
    }
  }
}

STATIC
VOID
DumpHobs (
  VOID
  )

{
  VOID               *HobStart;
  VOID               *Hob;
  UINTN              Total;
  UINTN              GuidTotal;
  EFI_HOB_GUID_TYPE  *GuidHob;
  UINTN              Printed;

  HobStart = GetHobList ();
  if (HobStart == NULL) {
    DEBUG ((DEBUG_ERROR, DTDUMP_TAG "hob list: none\n"));
    return;
  }

  Total     = 0;
  GuidTotal = 0;
  for (Hob = HobStart; !END_OF_HOB_LIST (Hob); Hob = GET_NEXT_HOB (Hob)) {
    Total++;
    if (Total > 8192) {
      break;
    }
    if (GET_HOB_TYPE (Hob) == EFI_HOB_TYPE_GUID_EXTENSION) {
      GuidTotal++;
    }
  }
  DEBUG ((DEBUG_ERROR, DTDUMP_TAG "hob list 0x%lx entries=%d guidhobs=%d\n",
          (UINT64)(UINTN)HobStart, Total, GuidTotal));

  Printed = 0;
  for (Hob = HobStart; !END_OF_HOB_LIST (Hob) && (Printed < 20); Hob = GET_NEXT_HOB (Hob)) {
    if (GET_HOB_TYPE (Hob) != EFI_HOB_TYPE_GUID_EXTENSION) {
      continue;
    }
    GuidHob = (EFI_HOB_GUID_TYPE *)Hob;
    Printed++;
    if (CompareGuid (&GuidHob->Name, &mDtbExtnHobGuid)) {
      UINT64  *Addr = (UINT64 *)GET_GUID_HOB_DATA (Hob);
      mDtbExtnAddr = *Addr;
      DEBUG ((DEBUG_ERROR, DTDUMP_TAG "  ^^^ DTB EXTENSION HOB %g addr=0x%lx\n",
              &GuidHob->Name, *Addr));
    } else if ((GuidHob->Name.Data1 == 0x90A49AFD) ||
               (GuidHob->Name.Data1 == 0xBEDAEABC) ||
               (GuidHob->Name.Data1 == 0xD5F8D706) ||
               (GuidHob->Name.Data1 == 0x8EC2BD8D) ||
               (GuidHob->Name.Data1 == 0x12DBD93D))
    {
      DumpHobWords (GuidHob, Hob);
      switch (GuidHob->Name.Data1) {
        case 0x90A49AFD: mInfoBlkAddr = *(UINT64 *)GET_GUID_HOB_DATA (Hob); break;
        case 0xBEDAEABC: mShimAddr    = *(UINT64 *)GET_GUID_HOB_DATA (Hob); break;
        case 0x8EC2BD8D: mSchedAddr   = *(UINT64 *)GET_GUID_HOB_DATA (Hob); break;
        default: break;
      }
    }
  }
}

STATIC
VOID
ProbeDtbExtn (
  VOID
  )
{
  EFI_STATUS  Status;
  VOID        *Ifc;
  UINT64      *Q;
  UINTN       Index;

  Ifc    = NULL;
  Status = gBS->LocateProtocol ((EFI_GUID *)&mDtbExtnProtoGuid, NULL, &Ifc);
  DEBUG ((DEBUG_ERROR, DTDUMP_TAG "DTBExtn protocol Status=%r ifc=0x%lx\n",
          Status, (UINT64)(UINTN)Ifc));
  if (EFI_ERROR (Status) || (Ifc == NULL)) {
    return;
  }
  Q = (UINT64 *)Ifc;
  for (Index = 0; Index < 8; Index++) {
    DEBUG ((DEBUG_ERROR, DTDUMP_TAG "  ifc[%d]=0x%lx\n", Index, Q[Index]));
  }
}

STATIC
UINT64
RdLe64 (
  IN CONST UINT8  *P
  )
{
  return ((UINT64)P[0]) | ((UINT64)P[1] << 8) | ((UINT64)P[2] << 16) | ((UINT64)P[3] << 24) |
         ((UINT64)P[4] << 32) | ((UINT64)P[5] << 40) | ((UINT64)P[6] << 48) | ((UINT64)P[7] << 56);
}

// 0xA7000000..0xA7FFFFFF is the "FD Reserved" window MemoryMapLib reports; it is mapped,
// so reading inside it cannot fault.  Everything else is touched only when we proved it safe.
STATIC
BOOLEAN
InFdWindow (
  IN UINT64  Addr
  )
{
  return (Addr >= 0xA7000000ULL) && (Addr < 0xA8000000ULL);
}

//
// The definitive question for U5: does XBL put a device tree *anywhere* in the mapped FD
// Reserved window?  FDT magic is the big-endian value 0x00D00DFEED, i.e. 0xEDFE0DD0 when the
// first four bytes are read as a little-endian UINT32.  Scanning 16 MiB of memory that is
// already mapped cannot fault, so this is a safe, one-shot answer.
//
STATIC
VOID
ScanWindowForFdt (
  VOID
  )
{
  UINT64        Addr;
  CONST UINT32  *P;
  UINTN         Hits;

  Hits = 0;
  for (Addr = 0xA7000000ULL; Addr < 0xA8000000ULL; Addr += 4) {
    P = (CONST UINT32 *)(UINTN)Addr;
    if (*P != 0xEDFE0DD0) {
      continue;
    }

    DEBUG ((
      DEBUG_ERROR,
      DTDUMP_TAG " FDT magic at 0x%lx totalsize=0x%x ver=0x%x\n",
      Addr,
      SwapBytes32 (P[1]),
      SwapBytes32 (P[2])
      ));
    if (++Hits >= 8) {
      break;
    }
  }

  DEBUG ((DEBUG_ERROR, DTDUMP_TAG " fdt scan done, hits=%d\n", Hits));
}

//
// EnvDxe copies 0x108 bytes from the address stored in the DT-extension HOB and treats the
// result as a protocol interface.  Its first 64-bit word is version-checked against 0x10005
// (EnvDxe+0x6068: ldr x9,[x8]; cmp x9,#0x10005) and a later indirect call uses the member at
// +0x58 (EnvDxe+0x6080/0x6088).  So if XBL really publishes a usable interface, some word in
// the mapped window equals 0x10005 -- and that address is the value our HOB should carry.
//
STATIC
VOID
ScanWindowForVer (
  VOID
  )
{
  UINT64        Addr;
  CONST UINT64  *P;
  UINTN         Hits;

  Hits = 0;
  for (Addr = 0xA7000000ULL; Addr < 0xA8000000ULL; Addr += 8) {
    P = (CONST UINT64 *)(UINTN)Addr;
    if (*P != 0x10005ULL) {
      continue;
    }

    DEBUG ((
      DEBUG_ERROR,
      DTDUMP_TAG " ifc? at 0x%lx: %lx %lx %lx %lx\n",
      Addr,
      P[0],
      P[1],
      P[2],
      P[3]
      ));
    if (++Hits >= 4) {
      break;
    }
  }

  DEBUG ((DEBUG_ERROR, DTDUMP_TAG " ver scan done, hits=%d\n", Hits));
}

STATIC
VOID
CheckFdtAt (
  IN UINT64  Addr
  );

//
// Independent of XblProtocols' (buggy) ADRP/ADD matching: brute-force the whole FD Reserved
// window for the DTB extension GUID and dump what follows it.  This tells us what XBL really
// published, and where the device tree / interface pointer lives.
//
STATIC
VOID
ScanWindowForGuid (
  VOID
  )
{
  UINT64       Addr;
  UINT64       Found;
  CONST UINT8  *P;
  UINTN        Index;

  Found = 0;
  DEBUG ((DEBUG_ERROR, DTDUMP_TAG "scan 0xA7000000..0xA8000000 for DTBExtnHobGuid\n"));
  for (Addr = 0xA7000000ULL; Addr < 0xA8000000ULL; Addr += 4) {
    if (((Addr & 0x3FFFFF) == 0) && (Addr != 0xA7000000ULL)) {
      DEBUG ((DEBUG_ERROR, DTDUMP_TAG " scan at 0x%lx\n", Addr));
    }
    P = (CONST UINT8 *)(UINTN)Addr;
    if (CompareMem (P, &mDtbExtnHobGuid, sizeof (EFI_GUID)) != 0) {
      continue;
    }
    Found++;
    DEBUG ((DEBUG_ERROR, DTDUMP_TAG " HIT guid at 0x%lx\n", Addr));
    // Layout guess: {GUID, value...}.  Print the words right after the GUID.
    DEBUG ((DEBUG_ERROR, DTDUMP_TAG "   +0x00 %016lx %016lx\n", RdLe64 (P), RdLe64 (P + 8)));
    DEBUG ((DEBUG_ERROR, DTDUMP_TAG "   +0x10 %016lx %016lx\n", RdLe64 (P + 16), RdLe64 (P + 24)));
    DEBUG ((DEBUG_ERROR, DTDUMP_TAG "   +0x20 %016lx %016lx\n", RdLe64 (P + 32), RdLe64 (P + 40)));
    DEBUG ((DEBUG_ERROR, DTDUMP_TAG "   +0x30 %016lx %016lx\n", RdLe64 (P + 48), RdLe64 (P + 56)));
    // The word after the GUID is the usual candidate for a payload pointer.
    for (Index = 16; Index <= 24; Index += 8) {
      CheckFdtAt (RdLe64 (P + Index));
    }
    if (Found >= 4) {
      DEBUG ((DEBUG_ERROR, DTDUMP_TAG " scan stopped after 4 hits\n"));
      return;
    }
  }
  DEBUG ((DEBUG_ERROR, DTDUMP_TAG " scan done, hits=%ld\n", Found));
}

STATIC
VOID
CheckFdtAt (
  IN UINT64  Addr
  )
{
  CONST UINT8  *P;
  UINT32       Magic;
  UINT32       TotalSize;

  if (!InFdWindow (Addr)) {
    DEBUG ((DEBUG_ERROR, DTDUMP_TAG " read 0x%lx: skipped (outside FD window)\n", Addr));
    return;
  }
  DEBUG ((DEBUG_ERROR, DTDUMP_TAG " read 0x%lx: ", Addr));
  P     = (CONST UINT8 *)(UINTN)Addr;
  Magic = RdBe32 (P);
  DEBUG ((DEBUG_ERROR, DTDUMP_TAG "magic=0x%08x hdr=%08x %08x %08x %08x\n",
          Magic, RdBe32 (P), RdBe32 (P + 4), RdBe32 (P + 8), RdBe32 (P + 12)));
  if (Magic != 0xD00DFEED) {
    return;
  }
  TotalSize = RdBe32 (P + 4);
  DEBUG ((DEBUG_ERROR, DTDUMP_TAG " FDT at 0x%lx totalsize=0x%x version=%d\n",
          Addr, TotalSize, (INT32)RdBe32 (P + 20)));
  if ((TotalSize > 0x40) && (TotalSize < 0x400000)) {
    WalkFdt (P, TotalSize);
  }
}

STATIC
VOID
AuditDtbAddr (
  VOID
  )
{
  CONST UINT8       *P;
  UINT64            W[4];
  UINTN             Index;
  EFI_GUID          Guid;
  UINT64            MaybeFdt;

  DEBUG ((DEBUG_ERROR, DTDUMP_TAG "dtb ext addr = 0x%lx\n", mDtbExtnAddr));
  DEBUG ((DEBUG_ERROR, DTDUMP_TAG " inside FD-Reserved(0xA7000000-0xA7FFFFFF) = %a\n",
          InFdWindow (mDtbExtnAddr) ? "YES" : "NO"));

  //
  // XblProtocols' ParseHobFunction returns the address of the GUID literal it found inside
  // XBL's "Basic HOB registration function", i.e. it is very likely a {GUID, value} entry,
  // not a device tree.  Dump it and check both interpretations.
  //
  if (InFdWindow (mDtbExtnAddr)) {
    P = (CONST UINT8 *)(UINTN)mDtbExtnAddr;
    for (Index = 0; Index < 4; Index++) {
      W[Index] = RdLe64 (P + Index * 8);
    }
    DEBUG ((DEBUG_ERROR, DTDUMP_TAG " entry[0..3] = %lx %lx %lx %lx\n",
            W[0], W[1], W[2], W[3]));
    CopyMem (&Guid, P, sizeof (Guid));
    DEBUG ((DEBUG_ERROR, DTDUMP_TAG " as guid = %g (match DTBExtnHob=%a)\n",
            &Guid, (CompareGuid (&Guid, &mDtbExtnHobGuid) ? "YES" : "NO")));
    // If that really is the HOB entry, the value after the GUID is the DT pointer.
    for (Index = 2; Index < 4; Index++) {
      MaybeFdt = W[Index];
      DEBUG ((DEBUG_ERROR, DTDUMP_TAG " candidate dt from entry+0x%x = 0x%lx\n",
              (UINT32)(Index * 8), MaybeFdt));
      CheckFdtAt (MaybeFdt);
    }
  }

  DEBUG ((DEBUG_ERROR, DTDUMP_TAG "dump-3 probe pages\n"));
  CheckFdtAt (0xA7000000ULL);
  CheckFdtAt (0xA7100000ULL);
  CheckFdtAt (0xA7FF0000ULL);
}

STATIC
CONST CHAR8 *
TypeName (
  IN UINT32  Type
  )
{
  switch (Type) {
    case 0: return "Reserved";
    case 1: return "LoaderCode";
    case 2: return "LoaderData";
    case 3: return "BS_Code";
    case 4: return "BS_Data";
    case 5: return "RT_Code";
    case 6: return "RT_Data";
    case 7: return "Conventional";
    case 8: return "Unusable";
    case 9: return "ACPI_Reclaim";
    case 10: return "ACPI_NVS";
    case 11: return "MMIO";
    case 12: return "MMIO_Port";
    case 13: return "PalCode";
    case 14: return "Persistent";
    default: return "?";
  }
}

//
// keys30: the DTB extension *interface* (0x108 bytes, word0 == 0x10005) lives in memory owned
// by XBL, not in the FD window we scanned so far.  Dump the memory map first (cheap + safe), so
// even if a later scan faults we already know which regions are worth probing.
//
STATIC
VOID
DumpMemoryMap (
  VOID
  )
{
  EFI_STATUS             Status;
  EFI_MEMORY_DESCRIPTOR  *Map;
  UINTN                  Size;
  UINTN                  MapKey;
  UINTN                  DescSize;
  UINT32                 DescVer;
  UINTN                  Count;
  UINTN                  Index;
  EFI_MEMORY_DESCRIPTOR  *D;

  Size   = 0;
  Status = gBS->GetMemoryMap (&Size, NULL, &MapKey, &DescSize, &DescVer);
  Size  += 8 * DescSize;
  Map    = NULL;
  Status = gBS->AllocatePool (EfiLoaderData, Size, (VOID **)&Map);
  if (EFI_ERROR (Status)) {
    DEBUG ((DEBUG_ERROR, DTDUMP_TAG "memmap: alloc failed %r\n", Status));
    return;
  }

  Status = gBS->GetMemoryMap (&Size, Map, &MapKey, &DescSize, &DescVer);
  if (EFI_ERROR (Status)) {
    DEBUG ((DEBUG_ERROR, DTDUMP_TAG "memmap: GetMemoryMap failed %r\n", Status));
    return;
  }

  Count = Size / DescSize;
  DEBUG ((DEBUG_ERROR, DTDUMP_TAG "==== memory map: %ld descriptors, descsize %ld ====\n",
          Count, DescSize));
  for (Index = 0; Index < Count; Index++) {
    D = (EFI_MEMORY_DESCRIPTOR *)((UINT8 *)Map + Index * DescSize);
    if ((D->Type == EfiReservedMemoryType) || (D->Type == EfiRuntimeServicesCode) ||
        (D->Type == EfiRuntimeServicesData) || (D->Type == EfiUnusableMemory) ||
        (D->Type == EfiACPIReclaimMemory) || (D->Type == EfiACPIMemoryNVS) ||
        (D->Type == EfiPersistentMemory))
    {
      DEBUG ((DEBUG_ERROR, DTDUMP_TAG "  [%02ld] %a base=0x%lx pages=%ld (0x%lx bytes)\n",
              Index, TypeName (D->Type), D->PhysicalStart, D->NumberOfPages,
              MultU64x64 (D->NumberOfPages, 4096)));
    }
  }

  gBS->FreePool (Map);
}

//
// keys30: hunt for the real DTB extension interface.  Signature: a UINT64 0x10005 at +0x00 and a
// non-null subtable pointer at +0x58 (EnvDxe's helper does ldr x8,[x8,#0x58]; ldr x8,[x8]; blr x8).
// Only Reserved/RT regions <= 32 MiB are scanned, 8-byte steps, to keep the fault risk low.
//
STATIC
VOID
ScanReservedForIfc (
  VOID
  )
{
  EFI_STATUS             Status;
  EFI_MEMORY_DESCRIPTOR  *Map;
  UINTN                  Size;
  UINTN                  MapKey;
  UINTN                  DescSize;
  UINT32                 DescVer;
  UINTN                  Count;
  UINTN                  Index;
  EFI_MEMORY_DESCRIPTOR  *D;
  UINT64                 Base;
  UINT64                 End;
  UINT64                 Addr;
  UINT64                 Sub;
  CONST UINT8            *P;
  UINTN                  Hits;

  Size   = 0;
  Status = gBS->GetMemoryMap (&Size, NULL, &MapKey, &DescSize, &DescVer);
  Size  += 8 * DescSize;
  Map    = NULL;
  Status = gBS->AllocatePool (EfiLoaderData, Size, (VOID **)&Map);
  if (EFI_ERROR (Status)) {
    DEBUG ((DEBUG_ERROR, DTDUMP_TAG "ifc scan: alloc failed %r\n", Status));
    return;
  }

  Status = gBS->GetMemoryMap (&Size, Map, &MapKey, &DescSize, &DescVer);
  if (EFI_ERROR (Status)) {
    DEBUG ((DEBUG_ERROR, DTDUMP_TAG "ifc scan: GetMemoryMap failed %r\n", Status));
    return;
  }

  Count = Size / DescSize;
  Hits  = 0;
  DEBUG ((DEBUG_ERROR, DTDUMP_TAG "==== hunt 0x10005 interface in reserved regions ====\n"));
  for (Index = 0; (Index < Count) && (Hits < 6); Index++) {
    D = (EFI_MEMORY_DESCRIPTOR *)((UINT8 *)Map + Index * DescSize);
    if ((D->Type != EfiReservedMemoryType) && (D->Type != EfiRuntimeServicesData)) {
      continue;
    }
    Base = D->PhysicalStart;
    End  = Base + MultU64x64 (D->NumberOfPages, 4096);
    if ((End - Base) > 0x2000000ULL) {
      DEBUG ((DEBUG_ERROR, DTDUMP_TAG " skip big region base=0x%lx bytes=0x%lx\n",
              Base, End - Base));
      continue;
    }
    if ((End - Base) < 0x200) {
      continue;
    }
    DEBUG ((DEBUG_ERROR, DTDUMP_TAG " scan %a base=0x%lx bytes=0x%lx\n",
            TypeName (D->Type), Base, End - Base));
    for (Addr = Base; (Addr + 0x108) <= End; Addr += 8) {
      if (RdLe64 ((CONST UINT8 *)(UINTN)Addr) != 0x10005ULL) {
        continue;
      }
      P   = (CONST UINT8 *)(UINTN)Addr;
      Sub = RdLe64 (P + 0x58);
      DEBUG ((DEBUG_ERROR, DTDUMP_TAG "  hit 0x%lx: ver=%lx w1=%lx sub58=0x%lx sub60=0x%lx\n",
              Addr, RdLe64 (P), RdLe64 (P + 8), Sub, RdLe64 (P + 0x60)));
      if (Hits >= 6) {
        break;
      }
    }
  }
  DEBUG ((DEBUG_ERROR, DTDUMP_TAG "ifc hunt done, hits=%ld\n", Hits));

  gBS->FreePool (Map);
}

//
// keys32: the generic "scan every reserved region" attempt is wrong on this board.  The stock
// NoMap windows (0x80000000+0x01200000, 0xFF800000) get a reservation HOB but NO MMU mapping,
// so reading them is a second-level translation fault: keys30/keys31 died with FAR=0x80000000,
// ESR=0x96000006.  Scan only windows the memory map really maps instead, and the most
// interesting one is literally called "XBL DT" (0x81A00000 + 0x40000).
//
STATIC
VOID
ScanMappedWindow (
  IN CONST CHAR8  *Name,
  IN UINT64       Base,
  IN UINT64       Size
  )
{
  CONST UINT8  *P;
  UINT8        *Q;
  UINT64       Addr;
  UINT64       End;
  UINT64       Sub;
  UINTN        VerHits;
  UINTN        GuidHits;
  UINT32       Magic;
  EFI_GUID     Guid;

  End      = Base + Size;
  VerHits  = 0;
  GuidHits = 0;
  P        = (CONST UINT8 *)(UINTN)Base;
  Magic    = RdBe32 (P);

  DEBUG ((DEBUG_ERROR, DTDUMP_TAG " win %a 0x%lx..0x%lx head=%08x %s\n",
          Name, Base, End, Magic, (Magic == 0xD00DFEED) ? "FDT!" : "no-fdt"));
  if (Magic == 0xD00DFEED) {
    WalkFdt (P, RdBe32 (P + 4));
  }

  for (Addr = Base; (Addr + 0x108) <= End; Addr += 8) {
    P = (CONST UINT8 *)(UINTN)Addr;
    if (RdLe64 (P) == 0x10005ULL) {
      Sub = RdLe64 (P + 0x58);
      DEBUG ((DEBUG_ERROR, DTDUMP_TAG "  ifc 0x%lx: ver=%lx w1=%lx sub58=0x%lx sub60=0x%lx\n",
              Addr, RdLe64 (P), RdLe64 (P + 8), Sub, RdLe64 (P + 0x60)));
      VerHits++;
      if (VerHits >= 3) {
        break;
      }
    }
  }

  for (Addr = Base; (Addr + 16) <= End; Addr += 4) {
    Q = (UINT8 *)(UINTN)Addr;
    CopyMem (&Guid, Q, sizeof (Guid));
    if (CompareGuid (&Guid, &mDtbExtnHobGuid)) {
      DEBUG ((DEBUG_ERROR, DTDUMP_TAG "  guid 0x%lx next=%lx %lx %lx\n",
              Addr, RdLe64 (Q + 16), RdLe64 (Q + 24), RdLe64 (Q + 32)));
      GuidHits++;
      if (GuidHits >= 3) {
        break;
      }
    }
  }

  DEBUG ((DEBUG_ERROR, DTDUMP_TAG " win %a done: ifc=%ld guid=%ld\n", Name, VerHits, GuidHits));
}

STATIC
VOID
ScanBoardWindows (
  VOID
  )
{
  DEBUG ((DEBUG_ERROR, DTDUMP_TAG "==== scan mapped windows ====\n"));
  ScanMappedWindow ("XBL DT",      0x81A00000ULL, 0x00040000ULL);
  ScanMappedWindow ("XBL Ramdump", 0x81A40000ULL, 0x001C0000ULL);
  ScanMappedWindow ("AOP",         0x81C00000ULL, 0x000A0000ULL);
  ScanMappedWindow ("UEFI Log",    0x81CE4000ULL, 0x00010000ULL);
  ScanMappedWindow ("SMEM",        0x81D00000ULL, 0x00200000ULL);
  ScanMappedWindow ("FD Reserved", 0xA7000000ULL, 0x00100000ULL);
  DEBUG ((DEBUG_ERROR, DTDUMP_TAG "==== window scan end ====\n"));
}
//
// keys33: our BootShim now publishes the x0 that ABL hands the boot image -- the live
// device tree -- at 0xA700FFF0: {u32 magic 0x46445442 ("BTDF" in memory), u64 fdt}.
// The reference K70 XNU bring-up (ios-vermeer-lab boot/loader.c) expects that pointer in
// 0xB5D00000..0xB5F00000, which our memory map already maps through the "Kernel"
// descriptor (0xA8000000 + 0x10000000), so both reading it and scanning that window are
// safe.  This is the tree the firmware never installed and every vendor driver wants.
//
#define DTDUMP_SHIM_SLOT   0xA700FFF0ULL
#define DTDUMP_SHIM_MAGIC  0x46445442U

STATIC
VOID
ProbeShimFdt (
  VOID
  )
{
  CONST UINT8  *Slot;
  UINT32       Magic;
  UINT64       Fdt;
  CONST UINT8  *P;
  UINT32       FdtMagic;
  UINT32       Total;
  UINT64       Probe;

  Slot  = (CONST UINT8 *)(UINTN)DTDUMP_SHIM_SLOT;
  Magic = (UINT32)(RdLe64 (Slot) & 0xFFFFFFFFULL);
  Fdt   = RdLe64 (Slot + 8);

  DEBUG ((DEBUG_ERROR, DTDUMP_TAG "==== shim live-FDT slot ====\n"));
  DEBUG ((DEBUG_ERROR, DTDUMP_TAG " slot 0x%lx magic=%08x (want %08x) fdt=0x%lx\n",
          DTDUMP_SHIM_SLOT, Magic, DTDUMP_SHIM_MAGIC, Fdt));

  if ((Magic == DTDUMP_SHIM_MAGIC) && (Fdt >= 0xA8000000ULL) && (Fdt < 0xB8000000ULL) &&
      ((Fdt & 3) == 0))
  {
    P        = (CONST UINT8 *)(UINTN)Fdt;
    FdtMagic = RdBe32 (P);
    Total    = RdBe32 (P + 4);
    DEBUG ((DEBUG_ERROR, DTDUMP_TAG " live fdt magic=%08x totalsize=0x%x %s\n",
            FdtMagic, Total, (FdtMagic == 0xD00DFEED) ? "OK" : "BAD"));
    if (FdtMagic == 0xD00DFEED) {
      WalkFdt (P, Total);
    }
  } else if (Magic == DTDUMP_SHIM_MAGIC) {
    DEBUG ((DEBUG_ERROR, DTDUMP_TAG " fdt 0x%lx outside the mapped Kernel window\n", Fdt));
  }

  DEBUG ((DEBUG_ERROR, DTDUMP_TAG " scan 0xB5D00000..0xB5F00000 for FDT magic\n"));
  for (Probe = 0xB5D00000ULL; Probe < 0xB5F00000ULL; Probe += 0x10000ULL) {
    P = (CONST UINT8 *)(UINTN)Probe;
    if (RdBe32 (P) == 0xD00DFEED) {
      DEBUG ((DEBUG_ERROR, DTDUMP_TAG " FDT found at 0x%lx totalsize=0x%x\n",
              Probe, RdBe32 (P + 4)));
      WalkFdt (P, RdBe32 (P + 4));
      break;
    }
  }
  DEBUG ((DEBUG_ERROR, DTDUMP_TAG "==== shim live-FDT slot end ====\n"));
}
STATIC CONST EFI_GUID  mGopGuid = {
  0x9042A9DE, 0x23DC, 0x4A38, { 0x96, 0xFB, 0x7A, 0xDE, 0xD0, 0x80, 0x51, 0x6A }
};

STATIC
VOID
PrintCon (
  IN CONST CHAR16  *Text
  )
{
  if ((gST != NULL) && (gST->ConOut != NULL)) {
    gST->ConOut->OutputString (gST->ConOut, (CHAR16 *)Text);
  }
}

//
// keys31: a tiny interactive console test.  Goals, in order of what it proves:
//   1. ConOut really reaches the panel (text printed through gST->ConOut, not only DEBUG).
//   2. Is there a Graphics Output Protocol (GOP) already?  That decides whether the next step
//      is "SimpleFbDxe / GOP menu" or "console only".
//   3. ConIn delivers key strokes with a usable ScanCode mapping (volume up/down).
// The driver never returns: the screen stays readable for photos.
//
STATIC
VOID
InteractiveDemo (
  VOID
  )
{
  EFI_STATUS   Status;
  EFI_INPUT_KEY Key;
  VOID         *Gop;
  UINTN        Sel;
  UINTN        Keys;
  CHAR16       Line[128];

  Sel  = 0;
  Keys = 0;
  Gop  = NULL;

  Status = gBS->LocateProtocol ((EFI_GUID *)&mGopGuid, NULL, &Gop);
  if (EFI_ERROR (Status)) {
    Gop = NULL;
  }

  DEBUG ((DEBUG_ERROR, DTDUMP_TAG "==== interactive console test ====\n"));
  DEBUG ((DEBUG_ERROR, DTDUMP_TAG " ConOut=%s ConIn=%s GOP=%s\n",
          ((gST != NULL) && (gST->ConOut != NULL)) ? "yes" : "no",
          ((gST != NULL) && (gST->ConIn != NULL)) ? "yes" : "no",
          (Gop != NULL) ? "yes" : "no"));

  //
  // Same three facts through the real console: if these lines show up on the panel, ConOut works
  // end to end; if they do not, everything we see is still the DEBUG framebuffer channel.
  //
  PrintCon (L"\r\n");
  UnicodeSPrint (Line, sizeof (Line), L"[UI] ConOut=%s ConIn=%s GOP=%s\r\n",
                 ((gST != NULL) && (gST->ConOut != NULL)) ? L"yes" : L"no",
                 ((gST != NULL) && (gST->ConIn != NULL)) ? L"yes" : L"no",
                 (Gop != NULL) ? L"yes" : L"no");
  PrintCon (Line);
  PrintCon (L"[UI] Vermeer console demo (keys31)\r\n");
  PrintCon (L"[UI] VOL-UP = previous, VOL-DOWN = next, long-press POWER to reboot\r\n");

  for ( ; ; ) {
    if ((gST == NULL) || (gST->ConIn == NULL)) {
      gBS->Stall (200 * 1000);
      continue;
    }
    Status = gST->ConIn->ReadKeyStroke (gST->ConIn, &Key);
    if (Status == EFI_NOT_READY) {
      gBS->Stall (20 * 1000);
      continue;
    }
    if (EFI_ERROR (Status)) {
      gBS->Stall (200 * 1000);
      continue;
    }

    if (Key.ScanCode == 0x01) {
      Sel = (Sel == 0) ? 3 : (Sel - 1);
    } else if (Key.ScanCode == 0x02) {
      Sel = (Sel + 1) % 4;
    }
    Keys++;

    DEBUG ((DEBUG_ERROR, DTDUMP_TAG " key #%ld ScanCode=0x%04x Unicode=0x%04x sel=%ld\n",
            Keys, Key.ScanCode, Key.UnicodeChar, Sel));
    UnicodeSPrint (Line, sizeof (Line),
                   L"[UI] key #%ld ScanCode=0x%04x -> selection [%ld]\r\n",
                   Keys, Key.ScanCode, Sel);
    PrintCon (Line);
    PrintCon (L"[UI]   [ ] 1  Show memory map\r\n");
    PrintCon (L"[UI]   [ ] 2  Hunt DTBExtn interface\r\n");
    PrintCon (L"[UI]   [ ] 3  Re-probe DTBExtn protocol\r\n");
    PrintCon (L"[UI]   [ ] 4  About this build\r\n");
  }
}

//
// keys35: dump the structures the HOB payloads point at.  Every candidate page is read word by
// word, and each word is FDT-magic checked, so a device tree hiding inside any of them shows up
// as an explicit "FDT!" line instead of another round trip.
//
STATIC
VOID
DumpWordsAt (
  IN CONST CHAR8  *What,
  IN UINT64       Addr,
  IN UINTN        Words
  )
{
  UINTN        Index;
  CONST UINT8  *P;
  UINT32       Magic;

  if (Addr == 0) {
    DEBUG ((DEBUG_ERROR, DTDUMP_TAG " %a: null\n", What));
    return;
  }
  //
  // Only addresses the firmware itself reported are touched here: they came out of the HOBs, so
  // they live in memory PEI already mapped (Info Blk ended up as an RT_Data page in the DXE map).
  //
  P     = (CONST UINT8 *)(UINTN)Addr;
  Magic = RdBe32 (P);
  DEBUG ((DEBUG_ERROR, DTDUMP_TAG " %a @0x%lx magic=%08x%s\n",
          What, Addr, Magic, (Magic == 0xD00DFEED) ? " FDT!" : ""));
  for (Index = 0; Index < Words; Index++) {
    DEBUG ((DEBUG_ERROR, DTDUMP_TAG "   [0x%x] %016lx\n", (UINT32)(Index * 8), RdLe64 (P + Index * 8)));
  }
  if (Magic == 0xD00DFEED) {
    WalkFdt (P, RdBe32 (P + 4));
    return;
  }
  for (Index = 0; Index < Words; Index++) {
    Magic = RdBe32 (P + Index * 8);
    if (Magic == 0xD00DFEED) {
      DEBUG ((DEBUG_ERROR, DTDUMP_TAG "   ^^ FDT at 0x%lx totalsize=0x%x\n",
              Addr + Index * 8, RdBe32 (P + Index * 8 + 4)));
      WalkFdt (P + Index * 8, RdBe32 (P + Index * 8 + 4));
    }
  }
}

STATIC
VOID
DumpHobPayloadPages (
  VOID
  )
{
  DEBUG ((DEBUG_ERROR, DTDUMP_TAG "==== hob payload pages ====\n"));
  DumpWordsAt ("InfoBlk", mInfoBlkAddr, 32);
  DumpWordsAt ("Shim",    mShimAddr,    16);
  DumpWordsAt ("Sched",   mSchedAddr,   16);
  DumpWordsAt ("DtbExtn", mDtbExtnAddr, 8);
  DEBUG ((DEBUG_ERROR, DTDUMP_TAG "==== hob payload pages end ====\n"));
}


STATIC EFI_EVENT  mUiEvent = NULL;

STATIC UINTN  mUiTicks = 0;
STATIC UINTN  mKeyCount = 0;
STATIC UINTN  mSel = 0;

STATIC
VOID
UiSay (
  IN CONST CHAR16  *Text
  )
{
  if (gST->ConOut != NULL) {
    gST->ConOut->OutputString (gST->ConOut, (CHAR16 *)Text);
  }
}

//
// keys39: every line is a fixed, formatter-free string, so nothing depends on DEBUG's %-handling
// (the previous build printed "ConIn=?er" because %s was fed a CHAR16 string).  The timer is
// periodic: each tick proves the event loop is alive and re-checks for a real ConIn.
//
STATIC
VOID
EFIAPI
UiNotify (
  IN EFI_EVENT  Event,
  IN VOID       *Context
  )
{
  EFI_STATUS  Status;
  EFI_INPUT_KEY Key;

  mUiTicks++;
  DEBUG ((DEBUG_ERROR, DTDUMP_TAG "ui tick\n"));
  UiSay (L"[UI] tick\r\n");

  if (gST->ConIn == NULL) {
    UiSay (L"[UI] ConIn = NULL\r\n");
  } else {
    UiSay (L"[UI] ConIn = present\r\n");
    Status = gST->ConIn->ReadKeyStroke (gST->ConIn, &Key);
    if (Status == EFI_SUCCESS) {
      mKeyCount++;
      if (Key.ScanCode == 0x01) {
        if (mSel > 0) mSel--;
        UiSay (L"[UI] KEY VOL-UP   -> selection\r\n");
      } else if (Key.ScanCode == 0x02) {
        mSel++;
        UiSay (L"[UI] KEY VOL-DOWN -> selection\r\n");
      } else {
        UiSay (L"[UI] KEY other\r\n");
      }
      UiSay (L"[UI] selected item below\r\n");
      if (mSel == 0) UiSay (L"[UI]  > 1  Console facts\r\n");
      if (mSel == 1) UiSay (L"[UI]  > 2  Memory map\r\n");
      if (mSel == 2) UiSay (L"[UI]  > 3  DTBExtn hunt\r\n");
      if (mSel == 3) UiSay (L"[UI]  > 4  About\r\n");
    }
  }

  if (gST->ConOut != NULL && (mUiTicks % 5) == 0) {
    UiSay (L"[UI] alive, keys seen so far: press VOL-UP / VOL-DOWN\r\n");
  }
}

//
// keys38: the probe is dispatched second, long before ConSplitter/GraphicsConsole exist, so the
// interactive part is armed as a 5 s one-shot timer instead of running inline.  By the time the
// timer fires, DXE dispatch has finished (or died), and gST->ConIn/ConOut are whatever BDS has.
//
STATIC
VOID
UiDeferredStart (
  VOID
  )
{
  EFI_STATUS  Status;

  Status = gBS->CreateEvent (EVT_TIMER, TPL_CALLBACK, UiNotify, NULL, &mUiEvent);
  if (EFI_ERROR (Status)) {
    DEBUG ((DEBUG_ERROR, DTDUMP_TAG "timer create failed: %r\n", Status));
    return;
  }
  gBS->SetTimer (mUiEvent, TimerPeriodic, 2ull * 1000ull * 1000ull * 10ull);
  DEBUG ((DEBUG_ERROR, DTDUMP_TAG "periodic UI armed (2 s)\n"));
}

STATIC
EFI_STATUS
EFIAPI
VermeerDtDumpDxeEntry (
  IN EFI_HANDLE        ImageHandle,
  IN EFI_SYSTEM_TABLE  *SystemTable
  )
{
  DEBUG ((DEBUG_ERROR, DTDUMP_TAG "==== vermeer device-tree dump ====\n"));
  //
  // keys34: only dump the GUID HOB payloads.  keys31/32 faulted on stock unmapped windows
  // (FAR=0x80000000) and keys33 never reached DXE at all, so this build keeps the handler
  // to pure HOB walking: every 64-bit word of every GUID HOB is printed, and any word that
  // points into the mapped Kernel window (0xA8000000..0xB8000000) is FDT-magic checked.
  //
  DumpHobs ();

  if (mLegacyProbe == 0) {
    //
    // keys37: no memory scanning at all (every previous crash came from touching a window that
    // the HOBs label Reserved but the page tables never map).  Only the console/GOP facts and
    // the button-driven menu are exercised, then the CPU parks.
    //
    //
    // Dead branch kept only so the crash-prone scanners stay referenced (-Werror=unused-function)
    // without ever running.  Never set mLegacyProbe to 2 on real hardware.
    //
    if (mLegacyProbe == 2) {
      InteractiveDemo ();
      ProbeShimFdt ();
      DumpMemoryMap ();
      ScanBoardWindows ();
      ScanReservedForIfc ();
      ProbeDtbExtn ();
      ScanWindowForVer ();
      ScanWindowForFdt ();
      AuditDtbAddr ();
      ScanWindowForGuid ();
    }

    DumpConfigTables ();
    //
    // keys40: InteractiveDemo() must NOT run here.  It blocks in ReadKeyStroke before
    // ConSplitter/GraphicsConsole exist, which is exactly why keys38/39 showed only the garbled
    // one-shot line and no tick.  The interactive part is the periodic timer below.
    //
  }

  DumpHobPayloadPages ();

  //
  // keys38: do NOT halt here.  Arm the console/UI check for later, then let DXE dispatch continue
  // so we can see whether EnvDxe survives without the DTB-Extension HOB.
  //
  UiDeferredStart ();

  return EFI_SUCCESS;
}
