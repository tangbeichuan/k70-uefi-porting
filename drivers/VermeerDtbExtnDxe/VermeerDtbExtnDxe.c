/** @file
  VermeerDtbExtnDxe -- publish the Qualcomm "DTB extension" protocol from our own device tree.

  Why this exists
  ---------------
  The SM8550 vendor DXE drivers (UFSDxe, HALIOMMU, PmicDxe, DisplayDxe, ...) do not read the
  Mu/EDK2 FDT configuration table.  They all do

      gBS->LocateProtocol (&gEfiDtbExtnProtocolGuid, NULL, &Ifc);
      Ifc->Method (node, "property", &value, sizeof value);

  with the protocol GUID 0389B776-625F-11EB-83BE-C741A913DE34.  In the stock firmware EnvDxe
  installs it by copying a 0x108-byte function-pointer table out of a DTB-extension HOB that XBL
  leaves in memory.  Our platform cannot get that HOB (see DTBExtn-接口逆向.md), and pushing a
  fake address through the PEI HOB makes EnvDxe crash.

  So we install the protocol ourselves, from a DXE driver, backed by the real firmware device
  tree that ships in the xbl_config partition (xbl_config_fdt_cb20.dtb -> FdtBlob/xbl_ufs.dtb in
  this FV).  The blob is embedded as a RAW FFS file so nothing has to be read from a block device.

  Interface layout (0x108 bytes, function pointers at fixed offsets), as used by UFSDxe.efi
  around file offset 0x17250 - 0x17460:

      +0x00  UINT64 Version          (checked >= 0x10005)
      +0x30  GetNode (VOID **Node, const CHAR8 *Path)
      +0x58  GetProp (VOID *Node, const CHAR8 *Name, VOID *Out, UINT32 Size)
      +0xa8  GetProp (same shape, used for multi-byte properties)
      +0xc8  GetPropByte (VOID *Node, const CHAR8 *Name, VOID *Out)

**/

#include <Uefi.h>
#include <Library/UefiBootServicesTableLib.h>
#include <Library/UefiLib.h>
#include <Library/DebugLib.h>
#include <Library/BaseLib.h>
#include <Library/BaseMemoryLib.h>
#include <Library/MemoryAllocationLib.h>
#include <Library/PrintLib.h>
#include <Library/DxeServicesLib.h>

//
// Protocol GUID used by the vendor drivers.
//
STATIC EFI_GUID  mDtbExtnProtocolGuid = {
  0x0389b776, 0x625f, 0x11eb, { 0x83, 0xbe, 0xc7, 0x41, 0xa9, 0x13, 0xde, 0x34 }
};

//
// FILE_GUID of the RAW FFS file that carries the device tree.
//
STATIC EFI_GUID  mDtbFileGuid = {
  0x7e5b1c3a, 0x9d24, 0x4e77, { 0x9c, 0x1b, 0x2a, 0x6d, 0x5f, 0x8e, 0x4c, 0x31 }
};

//
// EFI_DTB_TABLE (the standard Mu/EDK2 FDT configuration table GUID).
//
STATIC EFI_GUID  mFdtTableGuid = {
  0xb1b621d5, 0xf19c, 0x41a5, { 0x83, 0x0b, 0xd9, 0x15, 0x2c, 0x69, 0xaa, 0xe0 }
};

#define FDT_MAGIC             0xD00DFEEDU
#define FDT_BEGIN_NODE        0x00000001U
#define FDT_END_NODE          0x00000002U
#define FDT_PROP              0x00000003U
#define FDT_NOP               0x00000004U
#define FDT_END               0x00000009U

#define DTBEXTN_VERSION       0x10005ULL
#define DTBEXTN_IFC_SIZE      0x108

STATIC CONST UINT8  *mBlob;
STATIC UINT32        mBlobSize;
STATIC UINTN        mLastNode;
STATIC UINTN        mSeenKey[32];
STATIC UINT32       mSeenCount;
STATIC UINT32        mOffStruct;
STATIC UINT32        mOffStrings;

//
// keys139: node-box registry.
//
// The vendor ABI hands every method the *address of the caller's node box* (the same stack slot
// that GetNode filled through "VOID **Node"), never a dereferenced handle.  Remembering the
// (box address -> value) pair inside GetNode lets every other slot resolve the node without ever
// dereferencing a pointer we cannot prove is mapped (a Translation fault there is fatal in DXE).
//
#define DTBEXTN_MAX_BOX  32
STATIC UINTN   mBoxAddr[DTBEXTN_MAX_BOX];
STATIC UINTN   mBoxValue[DTBEXTN_MAX_BOX];
STATIC UINT32  mBoxCount;
STATIC UINT32  mBoxNext;

STATIC UINT32
Be32 (
  IN CONST UINT8  *P
  )
{
  return (UINT32)((P[0] << 24) | (P[1] << 16) | (P[2] << 8) | P[3]);
}

/**
  Return the offset that follows the node that starts at Off (its FDT_END_NODE + 4).
**/
STATIC
UINT32
FdtSkipNode (
  IN UINT32  Off
  )
{
  UINT32  Depth;
  UINT32  P;

  P     = Off;
  Depth = 0;
  while (P + 4 <= mBlobSize) {
    UINT32  Tok;

    Tok = Be32 (mBlob + P);
    P  += 4;
    switch (Tok) {
      case FDT_BEGIN_NODE:
        Depth++;
        //
        // Name is NUL-terminated and the whole (name + NUL) is padded to 4 bytes.
        // Next token starts at Align4(NulPos + 1), i.e. (NulPos + 4) & ~3.
        //
        while ((P < mBlobSize) && (mBlob[P] != 0)) {
          P++;
        }

        P = (P + 4) & ~3U;
        break;
      case FDT_END_NODE:
        Depth--;
        if (Depth == 0) {
          return P;
        }

        break;
      case FDT_PROP:
        if (P + 8 > mBlobSize) {
          return mBlobSize;
        }

        {
          UINT32  Len;

          Len = Be32 (mBlob + P);
          P  += 8;
          P  += (Len + 3) & ~3U;
        }

        break;
      case FDT_NOP:
        break;
      case FDT_END:
        return mBlobSize;
      default:
        return mBlobSize;
    }
  }

  return mBlobSize;
}

/**
  Split a device-tree path such as "/soc/ufs0/init_speed_params" and walk it.
  Unit addresses are ignored on comparison, so "ufs0" matches node "ufs0@1D80000".
**/
STATIC
BOOLEAN
NameMatches (
  IN CONST CHAR8  *NodeName,
  IN CONST CHAR8  *Want,
  IN UINTN        WantLen
  )
{
  UINTN  I;

  for (I = 0; I < WantLen; I++) {
    if (NodeName[I] != Want[I]) {
      return FALSE;
    }
  }

  if ((NodeName[WantLen] == 0) || (NodeName[WantLen] == '@')) {
    return TRUE;
  }

  return FALSE;
}

/**
  Scan the children of the node at ParentOff and return the one matching Comp/WantLen, or 0.
**/
STATIC
UINT32
FdtFindChild (
  IN UINT32       ParentOff,
  IN CONST CHAR8  *Comp,
  IN UINTN        CompLen
  )
{
  UINT32  P;
  UINT32  NameStart;

  //
  // ParentOff points at FDT_BEGIN_NODE; skip its own name first.
  // Next token starts at Align4(NulPos + 1) == (NulPos + 4) & ~3.
  //
  P = ParentOff + 4;
  while ((P < mBlobSize) && (mBlob[P] != 0)) {
    P++;
  }

  P = (P + 4) & ~3U;

  for (;;) {
    UINT32  Tok;

    if (P + 4 > mBlobSize) {
      return 0;
    }

    Tok = Be32 (mBlob + P);
    switch (Tok) {
      case FDT_BEGIN_NODE:
        NameStart = P + 4;
        if (NameMatches ((CONST CHAR8 *)(mBlob + NameStart), Comp, CompLen)) {
          return P;
        }

        P = FdtSkipNode (P);
        break;
      case FDT_PROP:
        if (P + 8 > mBlobSize) {
          return 0;
        }

        {
          UINT32  Len;

          //
          // P still points at the token here: len is at +4 and the data at +12.
          //
          Len = Be32 (mBlob + P + 4);
          P  += 12 + ((Len + 3) & ~3U);
        }

        break;
      case FDT_NOP:
        P += 4;
        break;
      case FDT_END_NODE:
      case FDT_END:
        return 0;
      default:
        return 0;
    }
  }
}

/**
  Print up to Max child names of the node at Node, for on-screen diagnostics.
**/
STATIC
VOID
FdtDumpChildren (
  IN UINT32  Node,
  IN UINT32  Max
  )
{
  UINT32  P;
  UINT32  Shown;

  if ((Node == 0) || (Node >= mBlobSize)) {
    DEBUG ((DEBUG_ERROR, "[DTBEXTN] children: bad node 0x%x\n", Node));
    return;
  }

  P = Node + 4;
  while ((P < mBlobSize) && (mBlob[P] != 0)) {
    P++;
  }

  P = (P + 4) & ~3U;
  Shown = 0;

  for (;;) {
    UINT32  Tok;

    if ((P + 4 > mBlobSize) || (Shown >= Max)) {
      break;
    }

    Tok = Be32 (mBlob + P);
    if (Tok == FDT_BEGIN_NODE) {
      DEBUG ((DEBUG_ERROR, "[DTBEXTN]  child: %a\n", (CONST CHAR8 *)(mBlob + P + 4)));
      Shown++;
      P = FdtSkipNode (P);
    } else if (Tok == FDT_PROP) {
      UINT32  Len;

      //
      // P still points at the token: len is at +4, data at +12.
      //
      Len = Be32 (mBlob + P + 4);
      P  += 12 + ((Len + 3) & ~3U);
    } else if (Tok == FDT_NOP) {
      P += 4;
    } else {
      break;
    }
  }

  DEBUG ((DEBUG_ERROR, "[DTBEXTN] children listed: %d\n", Shown));
}

STATIC
UINT32
FdtPathOffset (
  IN CONST CHAR8  *Path
  )
{
  UINT32       Node;
  CONST CHAR8  *P;

  Node = mOffStruct;
  P    = Path;

  while (*P != 0) {
    CONST CHAR8  *Slash;
    UINTN        Len;
    UINT32       Child;

    while (*P == '/') {
      P++;
    }

    if (*P == 0) {
      break;
    }

    Slash = P;
    while ((*Slash != 0) && (*Slash != '/')) {
      Slash++;
    }

    Len   = (UINTN)(Slash - P);
    Child = FdtFindChild (Node, P, Len);
    if (Child == 0) {
      return 0;
    }

    Node = Child;
    P    = Slash;
  }

  return Node;
}

/**
  Compare the FDT property name stored at (mOffStrings + NameOff) with Name, without ever reading
  past the end of the blob.

  keys139: the old code called AsciiStrCmp on a pointer derived straight from the strings block;
  a malformed NameOff could walk into unmapped memory.  This walks the blob instead.
**/
STATIC
BOOLEAN
FdtNameEquals (
  IN UINT32       NameOff,
  IN CONST CHAR8  *Name
  )
{
  UINT32  P;
  UINT32  I;

  if ((mBlob == NULL) || (Name == NULL) || (NameOff >= mBlobSize)) {
    return FALSE;
  }

  P = mOffStrings + NameOff;
  if (P >= mBlobSize) {
    return FALSE;
  }

  for (I = 0; (P + I) < mBlobSize; I++) {
    if (mBlob[P + I] != (UINT8)Name[I]) {
      return FALSE;
    }

    if (mBlob[P + I] == 0) {
      return TRUE;
    }
  }

  return FALSE;
}

/**
  Locate property Name of the node at offset Node.

  keys139: split out of FdtGetProp so that the "how long is this property" slot (+0x90) can be
  answered without copying anything.  Returns TRUE with DataOff/DataLen on success.
**/
STATIC
BOOLEAN
FdtFindProp (
  IN  UINT32       Node,
  IN  CONST CHAR8  *Name,
  OUT UINT32       *DataOff,
  OUT UINT32       *DataLen
  )
{
  UINT32  P;

  if ((mBlob == NULL) || (Node == 0) || (Node >= mBlobSize) || (Name == NULL)) {
    return FALSE;
  }

  //
  // Skip our own FDT_BEGIN_NODE name: align4(NulPos + 1) == (NulPos + 4) & ~3.
  //
  P = Node + 4;
  while ((P < mBlobSize) && (mBlob[P] != 0)) {
    P++;
  }

  P = (P + 4) & ~3U;

  for (;;) {
    UINT32  Tok;

    if (P + 4 > mBlobSize) {
      return FALSE;
    }

    Tok = Be32 (mBlob + P);
    if (Tok == FDT_END_NODE) {
      return FALSE;
    }

    if (Tok == FDT_PROP) {
      UINT32  Len;
      UINT32  NameOff;

      if (P + 12 > mBlobSize) {
        return FALSE;
      }

      Len     = Be32 (mBlob + P + 4);
      NameOff = Be32 (mBlob + P + 8);
      if (FdtNameEquals (NameOff, Name)) {
        if ((P + 12) > mBlobSize) {
          return FALSE;
        }

        if (Len > (mBlobSize - (P + 12))) {
          Len = mBlobSize - (P + 12);
        }

        if (DataOff != NULL) {
          *DataOff = P + 12;
        }

        if (DataLen != NULL) {
          *DataLen = Len;
        }

        return TRUE;
      }

      P += 12 + ((Len + 3) & ~3U);
    } else if (Tok == FDT_NOP) {
      P += 4;
    } else if (Tok == FDT_BEGIN_NODE) {
      P = FdtSkipNode (P);
    } else {
      return FALSE;
    }
  }
}

/**
  Copy property Name of Node into Out.

  Zero-fills the caller's buffer first (so short properties leave a deterministic tail), then
  copies min(property length, Size) bytes.  keys139: Size is always the caller's real buffer
  size -- never a 512-byte constant -- because PmicDxe's parser hands us 4-byte stack slots.
**/
STATIC
EFI_STATUS
FdtGetProp (
  IN UINT32       Node,
  IN CONST CHAR8  *Name,
  IN VOID         *Out,
  IN UINT32       Size
  )
{
  UINT32  DataOff;
  UINT32  Len;
  UINT32  Copy;

  if ((Out == NULL) || (Size == 0)) {
    return EFI_INVALID_PARAMETER;
  }

  if (!FdtFindProp (Node, Name, &DataOff, &Len)) {
    //
    // keys68/keys139: 属性不存在时必须回报 NOT_FOUND —— 厂商驱动靠这个分支走兜底路径。
    //
    return EFI_NOT_FOUND;
  }

  ZeroMem (Out, Size);
  Copy = (Len < Size) ? Len : Size;
  CopyMem (Out, mBlob + DataOff, Copy);
  return EFI_SUCCESS;
}

/**
  Return the offset of the first token that follows the node name of the node at Node
  (i.e. its first property or first child), or 0 when Node is unusable.
**/
STATIC
UINT32
FdtFirstChild (
  IN UINT32  Node
  )
{
  UINT32  P;

  if ((mBlob == NULL) || (Node == 0) || (Node >= mBlobSize)) {
    return 0;
  }

  P = Node + 4;
  while ((P < mBlobSize) && (mBlob[P] != 0)) {
    P++;
  }

  P = (P + 4) & ~3U;
  if (P >= mBlobSize) {
    return 0;
  }

  return P;
}

/**
  Number of *direct children* of the node at Node.  keys139: this is slot +0x28, which PmicDxe's
  VadcConfigParse calls right after the device properties (file offset 0x1f4b8) and treats a
  failure as fatal.
**/
STATIC
UINT32
FdtChildCount (
  IN UINT32  Node
  )
{
  UINT32  P;
  UINT32  Count;

  P = FdtFirstChild (Node);
  if (P == 0) {
    return 0;
  }

  Count = 0;
  for (;;) {
    UINT32  Tok;

    if (P + 4 > mBlobSize) {
      break;
    }

    Tok = Be32 (mBlob + P);
    if (Tok == FDT_BEGIN_NODE) {
      Count++;
      P = FdtSkipNode (P);
    } else if (Tok == FDT_PROP) {
      UINT32  Len;

      if (P + 8 > mBlobSize) {
        break;
      }

      Len = Be32 (mBlob + P + 4);
      P  += 12 + ((Len + 3) & ~3U);
    } else if (Tok == FDT_NOP) {
      P += 4;
    } else {
      //
      // FDT_END_NODE of the parent, FDT_END, or garbage: no more children.
      //
      break;
    }
  }

  return Count;
}

/**
  Return the blob offset of the NUL-terminated full name (including any "@unit") of the Index-th
  direct child of Node, or 0 when there is no such child.
**/
STATIC
UINT32
FdtChildNameAt (
  IN UINT32  Node,
  IN UINT32  Index
  )
{
  UINT32  P;
  UINT32  Seen;

  P = FdtFirstChild (Node);
  if (P == 0) {
    return 0;
  }

  Seen = 0;
  for (;;) {
    UINT32  Tok;

    if (P + 4 > mBlobSize) {
      return 0;
    }

    Tok = Be32 (mBlob + P);
    if (Tok == FDT_BEGIN_NODE) {
      if (Seen == Index) {
        return (P + 4 < mBlobSize) ? (P + 4) : 0;
      }

      Seen++;
      P = FdtSkipNode (P);
    } else if (Tok == FDT_PROP) {
      UINT32  Len;

      if (P + 8 > mBlobSize) {
        return 0;
      }

      Len = Be32 (mBlob + P + 4);
      P  += 12 + ((Len + 3) & ~3U);
    } else if (Tok == FDT_NOP) {
      P += 4;
    } else {
      return 0;
    }
  }
}

/**
  strlen() of the NUL-terminated name at blob offset NameOff, bounded by the blob end.
**/
STATIC
UINT32
FdtStrLen (
  IN UINT32  NameOff
  )
{
  UINT32  Len;

  for (Len = 0; (NameOff + Len) < mBlobSize; Len++) {
    if (mBlob[NameOff + Len] == 0) {
      break;
    }
  }

  return Len;
}

//
// The methods the vendor drivers call.
//
STATIC UINT32  mByteCallCount = 0;
STATIC UINT32  mCallCount;

/**
  TRUE when Addr lies inside the device tree blob.
**/
STATIC
BOOLEAN
InBlob (
  IN UINTN  Addr
  )
{
  return ((mBlob != NULL) && (Addr >= (UINTN)mBlob) &&
          (Addr < (UINTN)mBlob + mBlobSize)) ? TRUE : FALSE;
}

/**
  TRUE when it is safe to read 8 bytes at Addr.

  keys139: a blind *(UINT64 *)Node on a bogus box address is a Translation fault, and DXE has no
  exception handler for that.  We only ever dereference:
    - addresses inside the blob (bounds checked), or
    - addresses within 256 KiB of a local variable, i.e. the DXE boot stack, which is where every
      vendor caller keeps its node box (PmicDxe: "add x0, sp, #0x20").
  Heap boxes are still handled correctly: they are in the box registry, which needs no dereference.
**/
STATIC
BOOLEAN
SafeToRead (
  IN UINTN  Addr
  )
{
  volatile UINT8  Marker;
  UINTN           Here;

  if ((Addr & (sizeof (UINT64) - 1)) != 0) {
    return FALSE;
  }

  if (InBlob (Addr) && ((Addr + sizeof (UINT64)) <= ((UINTN)mBlob + mBlobSize))) {
    return TRUE;
  }

  Marker = 0;
  Here   = (UINTN)&Marker;
  if ((Addr >= Here) && (Addr < (Here + 0x40000))) {
    return TRUE;
  }

  return FALSE;
}

/**
  Remember the value GetNode stored into a caller-provided box.
**/
STATIC
VOID
RegisterBox (
  IN UINTN  Box,
  IN UINTN  Value
  )
{
  UINT32  I;

  if (Box == 0) {
    return;
  }

  for (I = 0; I < mBoxCount; I++) {
    if (mBoxAddr[I] == Box) {
      mBoxValue[I] = Value;
      return;
    }
  }

  if (mBoxCount < DTBEXTN_MAX_BOX) {
    mBoxAddr[mBoxCount]  = Box;
    mBoxValue[mBoxCount] = Value;
    mBoxCount++;
    return;
  }

  mBoxAddr[mBoxNext]  = Box;
  mBoxValue[mBoxNext] = Value;
  mBoxNext            = (mBoxNext + 1) % DTBEXTN_MAX_BOX;
}

/**
  Normalise what a vendor method received in x0 into a node *offset*.

  Three shapes have to be accepted:
    1. a raw node handle: either a pointer into the blob (what GetNode writes) or a small offset;
    2. the address of a caller node box that GetNode previously filled -- resolved through the
       registry, so no dereference is required;
    3. the same thing dereferenced (box in mapped memory) -- guarded by SafeToRead().
  mLastNode stays as the last-resort fallback it always was.
**/
STATIC
UINT32
NodeToOffset (
  IN VOID  *Node
  )
{
  UINTN   Value;
  UINTN   Raw;
  UINT32  I;

  Value = (UINTN)Node;
  if (Value == 0) {
    return 0;
  }

  if (InBlob (Value)) {
    return (UINT32)(Value - (UINTN)mBlob);
  }

  if (Value < mBlobSize) {
    return (UINT32)Value;
  }

  for (I = 0; I < mBoxCount; I++) {
    if (mBoxAddr[I] == Value) {
      Raw = mBoxValue[I];
      if (InBlob (Raw)) {
        return (UINT32)(Raw - (UINTN)mBlob);
      }

      if (Raw < mBlobSize) {
        return (UINT32)Raw;
      }
    }
  }

  if (SafeToRead (Value)) {
    Raw = *(UINTN *)Value;
    if (InBlob (Raw)) {
      return (UINT32)(Raw - (UINTN)mBlob);
    }

    if (Raw < mBlobSize) {
      return (UINT32)Raw;
    }
  }

  if (mLastNode != 0) {
    if (InBlob (mLastNode)) {
      return (UINT32)(mLastNode - (UINTN)mBlob);
    }

    return (UINT32)mLastNode;
  }

  return 0;
}

STATIC
EFI_STATUS
EfiApi_GetNode (
  OUT VOID         **Node,
  IN  CONST CHAR8  *Path
  )
{
  UINT32  Off;

  if ((Node == NULL) || (Path == NULL) || (mBlob == NULL)) {
    return EFI_NOT_FOUND;
  }

  Off = FdtPathOffset (Path);
  if (Off == 0) {
    if (mCallCount < 16) {
      mCallCount++;
      DEBUG ((DEBUG_ERROR, "[DTBEXTN] get node %a -> NOT FOUND\n", Path));
    }

    return EFI_NOT_FOUND;
  }

  *Node = (VOID *)(UINTN)(mBlob + Off);
  mLastNode = (UINTN)*Node;
  //
  // keys139: remember which caller box now holds which node, so the other slots can be resolved
  // without dereferencing an address we cannot prove is mapped.
  //
  RegisterBox ((UINTN)Node, (UINTN)*Node);
  if (mCallCount < 16) {
    mCallCount++;
    DEBUG ((DEBUG_ERROR, "[DTBEXTN] get node %a -> 0x%lx\n", Path, (UINT64)(UINTN)*Node));
  }

  return EFI_SUCCESS;
}

STATIC
EFI_STATUS
EfiApi_GetProp (
  IN  VOID         *Node,
  IN  CONST CHAR8  *Name,
  OUT VOID         *Out,
  IN  UINT32       Size
  )
{
  EFI_STATUS  Status;

  if ((mBlob == NULL) || (Name == NULL)) {
    return EFI_INVALID_PARAMETER;
  }

  Status = FdtGetProp (NodeToOffset (Node), Name, Out, Size);
  if (mCallCount < 16) {
    mCallCount++;
    DEBUG ((DEBUG_ERROR, "[DTBEXTN] get prop %a size=%d -> %r\n", Name, Size, Status));
  }

  return Status;
}

STATIC
EFI_STATUS
EfiApi_GetPropByte (
  IN  VOID         *Node,
  IN  CONST CHAR8  *Name,
  OUT VOID         *Out
  )
{
  EFI_STATUS  Status;

  if ((mBlob == NULL) || (Name == NULL)) {
    return EFI_INVALID_PARAMETER;
  }

  Status = FdtGetProp (NodeToOffset (Node), Name, Out, 1);
  if (mByteCallCount < 8) {
    mByteCallCount++;
    DEBUG ((DEBUG_ERROR, "[DTBEXTN] get prop BYTE %a -> %r\n", Name, Status));
  }

  return Status;
}


//
// keys60: 诊断辅助 —— 把 4 个入参都打出来，并把落在 blob 内的指针按字符串/字节解释。
//
STATIC VOID
LogArgs (
  IN CONST CHAR8  *Tag,
  IN UINTN         A0,
  IN UINTN         A1,
  IN UINTN         A2,
  IN UINTN         A3
  )
{
  DEBUG ((DEBUG_ERROR, "[DTBEXTN] %a args: %lx %lx %lx %lx\n", Tag, (UINT64)A0, (UINT64)A1, (UINT64)A2, (UINT64)A3));

  if ((A1 >= 0x80000000ULL) && (A1 < 0x100000000ULL)) {
    CONST UINT8  *B = (CONST UINT8 *)A1;
    DEBUG ((
      DEBUG_ERROR,
      "[DTBEXTN]   a1[0..15] = %02x %02x %02x %02x %02x %02x %02x %02x %02x %02x %02x %02x %02x %02x %02x %02x  '%c%c%c%c%c%c%c%c%c%c%c%c%c%c%c%c'\n",
      B[0], B[1], B[2], B[3], B[4], B[5], B[6], B[7],
      B[8], B[9], B[10], B[11], B[12], B[13], B[14], B[15],
      (B[0] >= 0x20 && B[0] < 0x7F) ? B[0] : '.',
      (B[1] >= 0x20 && B[1] < 0x7F) ? B[1] : '.',
      (B[2] >= 0x20 && B[2] < 0x7F) ? B[2] : '.',
      (B[3] >= 0x20 && B[3] < 0x7F) ? B[3] : '.',
      (B[4] >= 0x20 && B[4] < 0x7F) ? B[4] : '.',
      (B[5] >= 0x20 && B[5] < 0x7F) ? B[5] : '.',
      (B[6] >= 0x20 && B[6] < 0x7F) ? B[6] : '.',
      (B[7] >= 0x20 && B[7] < 0x7F) ? B[7] : '.',
      (B[8] >= 0x20 && B[8] < 0x7F) ? B[8] : '.',
      (B[9] >= 0x20 && B[9] < 0x7F) ? B[9] : '.',
      (B[10] >= 0x20 && B[10] < 0x7F) ? B[10] : '.',
      (B[11] >= 0x20 && B[11] < 0x7F) ? B[11] : '.',
      (B[12] >= 0x20 && B[12] < 0x7F) ? B[12] : '.',
      (B[13] >= 0x20 && B[13] < 0x7F) ? B[13] : '.',
      (B[14] >= 0x20 && B[14] < 0x7F) ? B[14] : '.',
      (B[15] >= 0x20 && B[15] < 0x7F) ? B[15] : '.'
      ));
  }

  if ((mBlob != NULL) && (A2 >= (UINTN)mBlob) && (A2 < (UINTN)mBlob + mBlobSize)) {
    DEBUG ((DEBUG_ERROR, "[DTBEXTN]   arg2 -> \"%a\"\n", (CONST CHAR8 *)A2));
  }
}

STATIC BOOLEAN
IsBlobPtr (
  IN UINTN  A
  )
{
  return ((mBlob != NULL) && ((CONST UINT8 *)A >= mBlob) && ((CONST UINT8 *)A < (mBlob + mBlobSize))) ? TRUE : FALSE;
}

STATIC BOOLEAN
LooksLikeName (
  IN UINTN  A
  )
{
  CONST UINT8  *B;

  if ((A < 0x80000000ULL) || (A >= 0x100000000ULL)) {
    return FALSE;
  }

  B = (CONST UINT8 *)A;
  return ((B[0] >= 0x20) && (B[0] < 0x7F) && (B[1] >= 0x20) && (B[1] < 0x7F) &&
          (B[2] >= 0x20) && (B[2] < 0x7F)) ? TRUE : FALSE;
}

//
// keys64：按"参数在哪个位置"反推 ABI。
// 观察到的事实：名字一定在某个参数里（如 "Signature"、"id"、"smpl-d..."），
// 节点句柄是落在 blob 里的指针，出参缓冲区在 DXE 栈上（0xA75xxxxx ~ 0xA79xxxxx）。
//
STATIC BOOLEAN
SeenBefore (
  IN UINT32  SlotId,
  IN UINTN   Name
  )
{
  UINT32  i;
  UINTN   Key;

  Key = ((UINTN)SlotId << 40) ^ (Name & 0xFFFFFFFFFFULL);

  for (i = 0; i < mSeenCount; i++) {
    if (mSeenKey[i] == Key) {
      return TRUE;
    }
  }

  if (mSeenCount < 32) {
    mSeenKey[mSeenCount++] = Key;
  }

  return FALSE;
}

STATIC EFI_STATUS
SlotGetGeneric (
  IN UINT32        SlotId,
  IN CONST CHAR8  *Tag,
  IN UINTN         A0,
  IN UINTN         A1,
  IN UINTN         A2,
  IN UINTN         A3,
  IN UINT32        MaxSize
  )
{
  UINTN       Args[4];
  UINTN       Name;
  UINTN       Out;
  UINT32      Off;
  UINT32      Size;
  EFI_STATUS  Status;
  UINTN       i;
  BOOLEAN     Quiet;

  Quiet = SeenBefore (SlotId, A1);
  if (!Quiet) {
    LogArgs (Tag, A0, A1, A2, A3);
  }

  Args[0] = A0; Args[1] = A1; Args[2] = A2; Args[3] = A3;
  Name = 0; Out = 0; Off = 0;

  //
  // keys139: resolve the node through NodeToOffset so both the "raw handle" and the vendor
  // "address of the caller's node box" forms work, and never derive an offset by subtracting
  // mBlob from a pointer we have not validated.
  //
  for (i = 0; i < 4; i++) {
    Off = NodeToOffset ((VOID *)Args[i]);
    if (Off != 0) {
      break;
    }
  }

  for (i = 0; i < 4; i++) {
    if ((!InBlob (Args[i])) && LooksLikeName (Args[i])) {
      Name = Args[i];
      break;
    }
  }

  for (i = 0; i < 4; i++) {
    if ((!IsBlobPtr (Args[i])) && (Args[i] != Name) &&
        (Args[i] >= 0xA7500000ULL) && (Args[i] < 0xA7A00000ULL))
    {
      Out = Args[i];
      break;
    }
  }

  if ((Off == 0) || (Name == 0) || (Out == 0)) {
    if (!Quiet) {
      DEBUG ((DEBUG_ERROR, "[DTBEXTN] %a -> unresolved (off=0x%x name=0x%lx out=0x%lx)\n",
              Tag, Off, (UINT64)Name, (UINT64)Out));
    }

    return EFI_NOT_FOUND;
  }

  //
  // keys139: never write more than the caller asked for.  This used to default to MaxSize (512),
  // which walked straight through PmicDxe's 0x190-byte frame; 4 bytes (one u32 cell) is the only
  // size that every slot shape can accept.
  //
  Size = sizeof (UINT32);
  if ((A3 > 0) && (A3 <= MaxSize)) {
    Size = (UINT32)A3;
  }

  Status = FdtGetProp (Off, (CONST CHAR8 *)Name, (VOID *)Out, Size);
  if (!Quiet) {
    DEBUG ((DEBUG_ERROR, "[DTBEXTN] %a -> node+0x%x name=\"%a\" out=0x%lx size=%d : %r\n",
            Tag, Off, (CONST CHAR8 *)Name, (UINT64)Out, Size, Status));
  }

  return Status;
}

//
// keys139: the slots PmicDxe's ADC parser (VadcConfigParse @ 0x1f114) and the rest of the PMIC
// driver call.  Every one of them receives the *address* of the caller's node box in x0, and all
// out-buffers are caller-owned stack slots of a size the vendor fixed by contract -- writing more
// than asked (the old "ZeroMem (Out, 512)") corrupts PmicDxe's 0x190-byte frame.
//

/**
  +0x28 (NodeBox, UINT32 *Count) -- number of direct child nodes.
**/
STATIC
EFI_STATUS
EfiApi_GetChildCount (
  IN UINTN  A0,
  IN UINTN  A1,
  IN UINTN  A2,
  IN UINTN  A3
  )
{
  UINT32  Node;
  UINT32  Count;

  Node = NodeToOffset ((VOID *)A0);
  if ((Node == 0) || (A1 == 0)) {
    DEBUG ((DEBUG_ERROR, "[DTBEXTN] +0x28 count: bad args (node=0x%x out=0x%lx)\n",
            Node, (UINT64)A1));
    return EFI_INVALID_PARAMETER;
  }

  Count     = FdtChildCount (Node);
  *(UINT32 *)A1 = Count;
  DEBUG ((DEBUG_ERROR, "[DTBEXTN] +0x28 count(node+0x%x) = %d\n", Node, Count));
  return EFI_SUCCESS;
}

/**
  +0x68 (NodeBox, UINT32 *Sizes, UINT32 Count) -- per-child name length, NUL included.
**/
STATIC
EFI_STATUS
EfiApi_GetChildNameSizes (
  IN UINTN  A0,
  IN UINTN  A1,
  IN UINTN  A2,
  IN UINTN  A3
  )
{
  UINT32  Node;
  UINT32  Count;
  UINT32  I;
  UINT32  NameOff;

  Node = NodeToOffset ((VOID *)A0);
  if ((Node == 0) || (A1 == 0)) {
    return EFI_INVALID_PARAMETER;
  }

  Count = (UINT32)A2;
  for (I = 0; I < Count; I++) {
    NameOff = FdtChildNameAt (Node, I);
    if (NameOff == 0) {
      ((UINT32 *)A1)[I] = 0;
      continue;
    }

    //
    // NUL included: PmicDxe only sums these to size the name buffer, then walks names with
    // AsciiStrLen, so "+1" is what keeps the total large enough.
    //
    ((UINT32 *)A1)[I] = FdtStrLen (NameOff) + 1;
  }

  DEBUG ((DEBUG_ERROR, "[DTBEXTN] +0x68 sizes(node+0x%x, n=%d) done\n", Node, Count));
  return EFI_SUCCESS;
}

/**
  +0x70 (NodeBox, CHAR8 *Buf, UINT32 Size) -- NUL-separated child node names (full names, i.e.
  with the "@unit" suffix, exactly as FDT stores them).
**/
STATIC
EFI_STATUS
EfiApi_GetChildNames (
  IN UINTN  A0,
  IN UINTN  A1,
  IN UINTN  A2,
  IN UINTN  A3
  )
{
  UINT32  Node;
  UINT32  Count;
  UINT32  Size;
  UINT32  Used;
  UINT32  I;
  UINT32  NameOff;
  UINT32  Len;

  Node = NodeToOffset ((VOID *)A0);
  if ((Node == 0) || (A1 == 0)) {
    return EFI_INVALID_PARAMETER;
  }

  Count = FdtChildCount (Node);
  Size  = (UINT32)A2;
  Used  = 0;
  for (I = 0; I < Count; I++) {
    NameOff = FdtChildNameAt (Node, I);
    if (NameOff == 0) {
      break;
    }

    Len = FdtStrLen (NameOff) + 1;
    if ((Used + Len) > Size) {
      DEBUG ((DEBUG_ERROR, "[DTBEXTN] +0x70 names: buffer too small (%d > %d)\n",
              Used + Len, Size));
      return EFI_BUFFER_TOO_SMALL;
    }

    CopyMem ((UINT8 *)A1 + Used, mBlob + NameOff, Len);
    Used += Len;
  }

  DEBUG ((DEBUG_ERROR, "[DTBEXTN] +0x70 names(node+0x%x) %d names, %d bytes\n",
          Node, Count, Used));
  return EFI_SUCCESS;
}

/**
  +0x90 (NodeBox, const CHAR8 *Name, UINT32 *Size) -- property length in bytes, no copy.

  PmicDxe uses it as "how much do I need to allocate for int-table / arb access masks".
**/
STATIC
EFI_STATUS
EfiApi_Slot90 (
  IN UINTN  A0,
  IN UINTN  A1,
  IN UINTN  A2,
  IN UINTN  A3
  )
{
  UINT32      Node;
  UINT32      DataOff;
  UINT32      Len;

  Node = NodeToOffset ((VOID *)A0);
  if ((Node == 0) || (A1 == 0) || (A2 == 0)) {
    return EFI_INVALID_PARAMETER;
  }

  if (!FdtFindProp (Node, (CONST CHAR8 *)A1, &DataOff, &Len)) {
    DEBUG ((DEBUG_ERROR, "[DTBEXTN] +0x90 size: \"%a\" NOT FOUND\n", (CONST CHAR8 *)A1));
    return EFI_NOT_FOUND;
  }

  *(UINT32 *)A2 = Len;
  DEBUG ((DEBUG_ERROR, "[DTBEXTN] +0x90 size \"%a\" = %d\n", (CONST CHAR8 *)A1, Len));
  return EFI_SUCCESS;
}

/**
  +0x98 / +0xa8 / +0x58 (NodeBox, const CHAR8 *Name, VOID *Out, UINT32 Size) -- copy Size bytes.
**/
STATIC
EFI_STATUS
EfiApi_GetPropCopy (
  IN UINTN  A0,
  IN UINTN  A1,
  IN UINTN  A2,
  IN UINTN  A3
  )
{
  UINT32      Node;
  EFI_STATUS  Status;

  Node = NodeToOffset ((VOID *)A0);
  if ((Node == 0) || (A1 == 0) || (A2 == 0) || (A3 == 0)) {
    return EFI_INVALID_PARAMETER;
  }

  Status = FdtGetProp (Node, (CONST CHAR8 *)A1, (VOID *)A2, (UINT32)A3);
  if (EFI_ERROR (Status)) {
    DEBUG ((DEBUG_ERROR, "[DTBEXTN] prop copy \"%a\" (node+0x%x, size=%d) -> %r\n",
            (CONST CHAR8 *)A1, Node, (UINT32)A3, Status));
  }

  return Status;
}

/**
  +0x88 / +0xa0 / +0xe0 (NodeBox, const CHAR8 *Name, UINT32 *Out) -- first cell as a u32.
**/
STATIC
EFI_STATUS
EfiApi_GetPropU32 (
  IN UINTN  A0,
  IN UINTN  A1,
  IN UINTN  A2,
  IN UINTN  A3
  )
{
  UINT32      Node;
  EFI_STATUS  Status;
  UINT32      Value;
  UINT8       Buf[sizeof (UINT32)];

  Node = NodeToOffset ((VOID *)A0);
  if ((Node == 0) || (A1 == 0) || (A2 == 0)) {
    return EFI_INVALID_PARAMETER;
  }

  Status = FdtGetProp (Node, (CONST CHAR8 *)A1, Buf, sizeof (Buf));
  if (EFI_ERROR (Status)) {
    DEBUG ((DEBUG_ERROR, "[DTBEXTN] prop u32 \"%a\" (node+0x%x) -> %r\n",
            (CONST CHAR8 *)A1, Node, Status));
    return Status;
  }

  CopyMem (&Value, Buf, sizeof (Value));
  *(UINT32 *)A2 = Value;
  return EFI_SUCCESS;
}

STATIC
EFI_STATUS
EfiApi_Slot88 (
  IN UINTN  A0,
  IN UINTN  A1,
  IN UINTN  A2,
  IN UINTN  A3
  )
{
  return EfiApi_GetPropU32 (A0, A1, A2, A3);
}

STATIC
EFI_STATUS
EfiApi_Slot98 (
  IN UINTN  A0,
  IN UINTN  A1,
  IN UINTN  A2,
  IN UINTN  A3
  )
{
  return EfiApi_GetPropCopy (A0, A1, A2, A3);
}

STATIC
EFI_STATUS
EfiApi_SlotA0 (
  IN UINTN  A0,
  IN UINTN  A1,
  IN UINTN  A2,
  IN UINTN  A3
  )
{
  return EfiApi_GetPropU32 (A0, A1, A2, A3);
}

STATIC
EFI_STATUS
EfiApi_SlotA8 (
  IN UINTN  A0,
  IN UINTN  A1,
  IN UINTN  A2,
  IN UINTN  A3
  )
{
  //
  // keys139: this used to be an unconditional EFI_NOT_FOUND, which alone made PmicDxe's VADC
  // parser fail.  +0xa8 has the same shape as +0x58: copy up to Size bytes.
  //
  return EfiApi_GetPropCopy (A0, A1, A2, A3);
}

STATIC
EFI_STATUS
EfiApi_SlotE0 (
  IN UINTN  A0,
  IN UINTN  A1,
  IN UINTN  A2,
  IN UINTN  A3
  )
{
  return EfiApi_GetPropU32 (A0, A1, A2, A3);
}

STATIC
EFI_STATUS
EfiApi_Slot20 (
  IN UINTN  A0,
  IN UINTN  A1,
  IN UINTN  A2,
  IN UINTN  A3
  )
{
  LogArgs ("slot 0x20", A0, A1, A2, A3);
  return SlotGetGeneric (0x20, "slot 0x20", A0, A1, A2, A3, 512);
}

STATIC
EFI_STATUS
EfiApi_Slot40 (
  IN UINTN  A0,
  IN UINTN  A1,
  IN UINTN  A2,
  IN UINTN  A3
  )
{
  return SlotGetGeneric (0x40, "slot 0x40", A0, A1, A2, A3, 512);
}

//
// keys59: 每个未实现槽位一个独立函数，打印自己的偏移 + 调用者 LR。
//
STATIC EFI_STATUS
EfiApi_Unsup_008 (
  VOID
  )
{
  DEBUG ((
    DEBUG_ERROR,
    "[DTBEXTN] slot 0x008 called, LR=0x%lx\n",
    (UINT64)(UINTN)__builtin_return_address (0)
    ));
  return EFI_NOT_FOUND;
}

STATIC EFI_STATUS
EfiApi_Unsup_010 (
  VOID
  )
{
  DEBUG ((
    DEBUG_ERROR,
    "[DTBEXTN] slot 0x010 called, LR=0x%lx\n",
    (UINT64)(UINTN)__builtin_return_address (0)
    ));
  return EFI_NOT_FOUND;
}

STATIC EFI_STATUS
EfiApi_Unsup_018 (
  VOID
  )
{
  DEBUG ((
    DEBUG_ERROR,
    "[DTBEXTN] slot 0x018 called, LR=0x%lx\n",
    (UINT64)(UINTN)__builtin_return_address (0)
    ));
  return EFI_NOT_FOUND;
}

STATIC EFI_STATUS
EfiApi_Unsup_020 (
  VOID
  )
{
  DEBUG ((
    DEBUG_ERROR,
    "[DTBEXTN] slot 0x020 called, LR=0x%lx\n",
    (UINT64)(UINTN)__builtin_return_address (0)
    ));
  return EFI_NOT_FOUND;
}

STATIC EFI_STATUS
EfiApi_Unsup_028 (
  VOID
  )
{
  DEBUG ((
    DEBUG_ERROR,
    "[DTBEXTN] slot 0x028 called, LR=0x%lx\n",
    (UINT64)(UINTN)__builtin_return_address (0)
    ));
  return EFI_NOT_FOUND;
}

STATIC EFI_STATUS
EfiApi_Unsup_038 (
  VOID
  )
{
  DEBUG ((
    DEBUG_ERROR,
    "[DTBEXTN] slot 0x038 called, LR=0x%lx\n",
    (UINT64)(UINTN)__builtin_return_address (0)
    ));
  return EFI_NOT_FOUND;
}

STATIC EFI_STATUS
EfiApi_Unsup_040 (
  VOID
  )
{
  DEBUG ((
    DEBUG_ERROR,
    "[DTBEXTN] slot 0x040 called, LR=0x%lx\n",
    (UINT64)(UINTN)__builtin_return_address (0)
    ));
  return EFI_NOT_FOUND;
}

STATIC EFI_STATUS
EfiApi_Unsup_048 (
  VOID
  )
{
  DEBUG ((
    DEBUG_ERROR,
    "[DTBEXTN] slot 0x048 called, LR=0x%lx\n",
    (UINT64)(UINTN)__builtin_return_address (0)
    ));
  return EFI_NOT_FOUND;
}

STATIC EFI_STATUS
EfiApi_Unsup_050 (
  VOID
  )
{
  DEBUG ((
    DEBUG_ERROR,
    "[DTBEXTN] slot 0x050 called, LR=0x%lx\n",
    (UINT64)(UINTN)__builtin_return_address (0)
    ));
  return EFI_NOT_FOUND;
}

STATIC EFI_STATUS
EfiApi_Unsup_060 (
  VOID
  )
{
  DEBUG ((
    DEBUG_ERROR,
    "[DTBEXTN] slot 0x060 called, LR=0x%lx\n",
    (UINT64)(UINTN)__builtin_return_address (0)
    ));
  return EFI_NOT_FOUND;
}

STATIC EFI_STATUS
EfiApi_Unsup_068 (
  VOID
  )
{
  DEBUG ((
    DEBUG_ERROR,
    "[DTBEXTN] slot 0x068 called, LR=0x%lx\n",
    (UINT64)(UINTN)__builtin_return_address (0)
    ));
  return EFI_NOT_FOUND;
}

STATIC EFI_STATUS
EfiApi_Unsup_070 (
  VOID
  )
{
  DEBUG ((
    DEBUG_ERROR,
    "[DTBEXTN] slot 0x070 called, LR=0x%lx\n",
    (UINT64)(UINTN)__builtin_return_address (0)
    ));
  return EFI_NOT_FOUND;
}

STATIC EFI_STATUS
EfiApi_Unsup_078 (
  VOID
  )
{
  DEBUG ((
    DEBUG_ERROR,
    "[DTBEXTN] slot 0x078 called, LR=0x%lx\n",
    (UINT64)(UINTN)__builtin_return_address (0)
    ));
  return EFI_NOT_FOUND;
}

STATIC EFI_STATUS
EfiApi_Unsup_080 (
  VOID
  )
{
  DEBUG ((
    DEBUG_ERROR,
    "[DTBEXTN] slot 0x080 called, LR=0x%lx\n",
    (UINT64)(UINTN)__builtin_return_address (0)
    ));
  return EFI_NOT_FOUND;
}

STATIC EFI_STATUS
EfiApi_Unsup_088 (
  VOID
  )
{
  DEBUG ((
    DEBUG_ERROR,
    "[DTBEXTN] slot 0x088 called, LR=0x%lx\n",
    (UINT64)(UINTN)__builtin_return_address (0)
    ));
  return EFI_NOT_FOUND;
}

STATIC EFI_STATUS
EfiApi_Unsup_090 (
  VOID
  )
{
  DEBUG ((
    DEBUG_ERROR,
    "[DTBEXTN] slot 0x090 called, LR=0x%lx\n",
    (UINT64)(UINTN)__builtin_return_address (0)
    ));
  return EFI_NOT_FOUND;
}

STATIC EFI_STATUS
EfiApi_Unsup_098 (
  VOID
  )
{
  DEBUG ((
    DEBUG_ERROR,
    "[DTBEXTN] slot 0x098 called, LR=0x%lx\n",
    (UINT64)(UINTN)__builtin_return_address (0)
    ));
  return EFI_NOT_FOUND;
}

STATIC EFI_STATUS
EfiApi_Unsup_0a0 (
  VOID
  )
{
  DEBUG ((
    DEBUG_ERROR,
    "[DTBEXTN] slot 0x0a0 called, LR=0x%lx\n",
    (UINT64)(UINTN)__builtin_return_address (0)
    ));
  return EFI_NOT_FOUND;
}

STATIC EFI_STATUS
EfiApi_Unsup_0b0 (
  VOID
  )
{
  DEBUG ((
    DEBUG_ERROR,
    "[DTBEXTN] slot 0x0b0 called, LR=0x%lx\n",
    (UINT64)(UINTN)__builtin_return_address (0)
    ));
  return EFI_NOT_FOUND;
}

STATIC EFI_STATUS
EfiApi_Unsup_0b8 (
  VOID
  )
{
  DEBUG ((
    DEBUG_ERROR,
    "[DTBEXTN] slot 0x0b8 called, LR=0x%lx\n",
    (UINT64)(UINTN)__builtin_return_address (0)
    ));
  return EFI_NOT_FOUND;
}

STATIC EFI_STATUS
EfiApi_Unsup_0c0 (
  VOID
  )
{
  DEBUG ((
    DEBUG_ERROR,
    "[DTBEXTN] slot 0x0c0 called, LR=0x%lx\n",
    (UINT64)(UINTN)__builtin_return_address (0)
    ));
  return EFI_NOT_FOUND;
}

STATIC EFI_STATUS
EfiApi_Unsup_0d0 (
  VOID
  )
{
  DEBUG ((
    DEBUG_ERROR,
    "[DTBEXTN] slot 0x0d0 called, LR=0x%lx\n",
    (UINT64)(UINTN)__builtin_return_address (0)
    ));
  return EFI_NOT_FOUND;
}

STATIC EFI_STATUS
EfiApi_Unsup_0d8 (
  VOID
  )
{
  DEBUG ((
    DEBUG_ERROR,
    "[DTBEXTN] slot 0x0d8 called, LR=0x%lx\n",
    (UINT64)(UINTN)__builtin_return_address (0)
    ));
  return EFI_NOT_FOUND;
}

STATIC EFI_STATUS
EfiApi_Unsup_0e0 (
  VOID
  )
{
  DEBUG ((
    DEBUG_ERROR,
    "[DTBEXTN] slot 0x0e0 called, LR=0x%lx\n",
    (UINT64)(UINTN)__builtin_return_address (0)
    ));
  return EFI_NOT_FOUND;
}

STATIC EFI_STATUS
EfiApi_Unsup_0e8 (
  VOID
  )
{
  DEBUG ((
    DEBUG_ERROR,
    "[DTBEXTN] slot 0x0e8 called, LR=0x%lx\n",
    (UINT64)(UINTN)__builtin_return_address (0)
    ));
  return EFI_NOT_FOUND;
}

STATIC EFI_STATUS
EfiApi_Unsup_0f0 (
  VOID
  )
{
  DEBUG ((
    DEBUG_ERROR,
    "[DTBEXTN] slot 0x0f0 called, LR=0x%lx\n",
    (UINT64)(UINTN)__builtin_return_address (0)
    ));
  return EFI_NOT_FOUND;
}

STATIC EFI_STATUS
EfiApi_Unsup_0f8 (
  VOID
  )
{
  DEBUG ((
    DEBUG_ERROR,
    "[DTBEXTN] slot 0x0f8 called, LR=0x%lx\n",
    (UINT64)(UINTN)__builtin_return_address (0)
    ));
  return EFI_NOT_FOUND;
}

STATIC EFI_STATUS
EfiApi_Unsup_100 (
  VOID
  )
{
  DEBUG ((
    DEBUG_ERROR,
    "[DTBEXTN] slot 0x100 called, LR=0x%lx\n",
    (UINT64)(UINTN)__builtin_return_address (0)
    ));
  return EFI_NOT_FOUND;
}

STATIC CONST struct {
  UINTN    Off;
  VOID     *Fn;
} mStubTable[] = {
  { 0x008, (VOID *)EfiApi_Unsup_008 },
  { 0x010, (VOID *)EfiApi_Unsup_010 },
  { 0x018, (VOID *)EfiApi_Unsup_018 },
  { 0x020, (VOID *)EfiApi_Unsup_020 },
  { 0x028, (VOID *)EfiApi_Unsup_028 },
  { 0x038, (VOID *)EfiApi_Unsup_038 },
  { 0x040, (VOID *)EfiApi_Unsup_040 },
  { 0x048, (VOID *)EfiApi_Unsup_048 },
  { 0x050, (VOID *)EfiApi_Unsup_050 },
  { 0x060, (VOID *)EfiApi_Unsup_060 },
  { 0x068, (VOID *)EfiApi_Unsup_068 },
  { 0x070, (VOID *)EfiApi_Unsup_070 },
  { 0x078, (VOID *)EfiApi_Unsup_078 },
  { 0x080, (VOID *)EfiApi_Unsup_080 },
  { 0x088, (VOID *)EfiApi_Unsup_088 },
  { 0x090, (VOID *)EfiApi_Unsup_090 },
  { 0x098, (VOID *)EfiApi_Unsup_098 },
  { 0x0a0, (VOID *)EfiApi_Unsup_0a0 },
  { 0x0b0, (VOID *)EfiApi_Unsup_0b0 },
  { 0x0b8, (VOID *)EfiApi_Unsup_0b8 },
  { 0x0c0, (VOID *)EfiApi_Unsup_0c0 },
  { 0x0d0, (VOID *)EfiApi_Unsup_0d0 },
  { 0x0d8, (VOID *)EfiApi_Unsup_0d8 },
  { 0x0e0, (VOID *)EfiApi_Unsup_0e0 },
  { 0x0e8, (VOID *)EfiApi_Unsup_0e8 },
  { 0x0f0, (VOID *)EfiApi_Unsup_0f0 },
  { 0x0f8, (VOID *)EfiApi_Unsup_0f8 },
  { 0x100, (VOID *)EfiApi_Unsup_100 },
};

//
// The 0x108-byte interface.  Only the four used slots plus the version word are populated.
//
typedef struct {
  UINT64           Version;                    // +0x00
  UINT8            Pad0[0x30 - 0x08];          // +0x08 .. +0x2f
  VOID             *GetNode;                   // +0x30
  UINT8            Pad1[0x58 - 0x38];          // +0x38 .. +0x57
  VOID             *GetPropA;                  // +0x58
  UINT8            Pad2[0xa8 - 0x60];          // +0x60 .. +0xa7
  VOID             *GetPropB;                  // +0xa8
  UINT8            Pad3[0xc8 - 0xb0];          // +0xb0 .. +0xc7
  VOID             *GetPropByte;               // +0xc8
  UINT8            Pad4[DTBEXTN_IFC_SIZE - 0xd0];
} DTBEXTN_INTERFACE;

/**
  Catch-all for interface slots we do not implement.

  Several vendor drivers (DALTLMM, PmicDxe, DisplayDxe, ...) fetch this protocol and may call
  methods other than the four UFSDxe uses.  A NULL slot turns those into "jump to address 0"
  (keys49 crashed at PC=0x0 inside DALTLMM.dll exactly like that), so every non-implemented slot
  points here instead: the call returns EFI_NOT_FOUND and the driver survives.
**/
STATIC
EFI_STATUS
EfiApi_Unsupported (
  VOID
  )
{
  VOID  *Caller;

  Caller = __builtin_return_address (0);
  DEBUG ((
    DEBUG_ERROR,
    "[DTBEXTN] UNSUPPORTED slot called (now returning SUCCESS), LR=0x%lx\n",
    (UINT64)(UINTN)Caller
    ));
  return EFI_SUCCESS;
}

STATIC DTBEXTN_INTERFACE  mInterface;
STATIC BOOLEAN            mInstalled;

STATIC
VOID
SetIfcSlot (
  IN UINT32  Offset,
  IN VOID    *Function
  )
{
  UINT8  *Base;
  UINT64  Value;

  Base  = (UINT8 *)&mInterface;
  Value = (UINT64)(UINTN)Function;
  CopyMem (Base + Offset, &Value, sizeof (Value));
}

EFI_STATUS
EFIAPI
VermeerDtbExtnDxeEntry (
  IN EFI_HANDLE        ImageHandle,
  IN EFI_SYSTEM_TABLE  *SystemTable
  )
{
  EFI_STATUS  Status;
  UINT32      TotalSize;

  DEBUG ((DEBUG_ERROR, "[DTBEXTN] ==== vermeer dtb-extn provider ====\n"));

  Status = GetSectionFromAnyFv (
             &mDtbFileGuid,
             EFI_SECTION_RAW,
             0,
             (VOID **)&mBlob,
             (UINTN *)&mBlobSize
             );
  if (EFI_ERROR (Status) || (mBlob == NULL)) {
    DEBUG ((DEBUG_ERROR, "[DTBEXTN] dtb blob not found in FV: %r\n", Status));
    return EFI_SUCCESS;                       // do not fail the dispatch
  }

  TotalSize = mBlobSize;
  if ((mBlobSize < 0x28) || (Be32 (mBlob) != FDT_MAGIC)) {
    DEBUG ((DEBUG_ERROR, "[DTBEXTN] blob is not an FDT (size=%d magic=0x%x)\n",
            TotalSize, Be32 (mBlob)));
    return EFI_SUCCESS;
  }

  mOffStruct  = Be32 (mBlob + 8);
  mOffStrings = Be32 (mBlob + 12);
  if ((mOffStruct >= mBlobSize) || (mOffStrings >= mBlobSize)) {
    DEBUG ((DEBUG_ERROR, "[DTBEXTN] bad FDT header (struct=0x%x strings=0x%x)\n",
            mOffStruct, mOffStrings));
    return EFI_SUCCESS;
  }

  DEBUG ((DEBUG_ERROR,
          "[DTBEXTN] blob 0x%lx size=%d struct=0x%x strings=0x%x\n",
          (UINT64)(UINTN)mBlob, TotalSize, mOffStruct, mOffStrings));

  ZeroMem (&mInterface, sizeof (mInterface));
  mInterface.Version = DTBEXTN_VERSION;

  //
  // Fill every slot with the safe stub first, then install the four real methods.
  // A NULL slot makes an unknown method call jump to address 0 and kills the boot.
  //
  {
    UINT32  Off;

    for (Off = 0; Off < (sizeof (mStubTable) / sizeof (mStubTable[0])); Off++) {
      SetIfcSlot (mStubTable[Off].Off, mStubTable[Off].Fn);
    }
    if (FALSE) {
      SetIfcSlot (DTBEXTN_IFC_SIZE, (VOID *)EfiApi_Unsupported);
    }
    // keys60: 被 vendor 真实调用的槽位，用带参数日志的桩覆盖
    SetIfcSlot (0x40, (VOID *)EfiApi_Slot40);
    SetIfcSlot (0x88, (VOID *)EfiApi_Slot88);
    SetIfcSlot (0x90, (VOID *)EfiApi_Slot90);
    SetIfcSlot (0xa0, (VOID *)EfiApi_SlotA0);
    SetIfcSlot (0x98, (VOID *)EfiApi_Slot98);
    SetIfcSlot (0x20, (VOID *)EfiApi_Slot20);
    //
    // keys139: the child-node walker PmicDxe's VADC parser needs before it will look at a single
    // channel: +0x28 count, +0x68 name sizes, +0x70 names.
    //
    SetIfcSlot (0x28, (VOID *)EfiApi_GetChildCount);
    SetIfcSlot (0x68, (VOID *)EfiApi_GetChildNameSizes);
    SetIfcSlot (0x70, (VOID *)EfiApi_GetChildNames);
    SetIfcSlot (0xe0, (VOID *)EfiApi_SlotE0);
  }

  SetIfcSlot (0x30, (VOID *)EfiApi_GetNode);
  SetIfcSlot (0x58, (VOID *)EfiApi_GetProp);
  SetIfcSlot (0xa8, (VOID *)EfiApi_SlotA8);
  SetIfcSlot (0xc8, (VOID *)EfiApi_GetPropByte);

  //
  // Self test so the screen tells us the parser works even if nothing consumes the protocol.
  //
  {
    VOID    *Node;
    UINT64  Reg;
    UINT8   Fua;
    UINT32  Timeout;

    Node = NULL;
    if (!EFI_ERROR (EfiApi_GetNode (&Node, "/soc/ufs0"))) {
      EFI_STATUS  S1;
      EFI_STATUS  S2;
      EFI_STATUS  S3;
      VOID        *TNode;

      S1 = EfiApi_GetProp (Node, "reg", &Reg, sizeof (Reg));
      S2 = EfiApi_GetPropByte (Node, "FUA_Value", &Fua);
      TNode = NULL;
      S3    = EfiApi_GetNode (&TNode, "/soc/ufs0/timeout_values");
      Timeout = 0;
      if (!EFI_ERROR (S3)) {
        EfiApi_GetProp (TNode, "fDeviceInitTimeoutUs", &Timeout, sizeof (Timeout));
      }

      DEBUG ((DEBUG_ERROR,
              "[DTBEXTN] selftest ufs0: reg=0x%lx (want 0x1d80000) fua=%d timeout=0x%x s=%r/%r/%r\n",
              Reg, (UINT32)Fua, Timeout, S1, S2, S3));
    } else {
      DEBUG ((DEBUG_ERROR, "[DTBEXTN] selftest: /soc/ufs0 NOT FOUND\n"));
      FdtDumpChildren (mOffStruct, 6);
      if (FdtFindChild (mOffStruct, "soc", 3) != 0) {
        FdtDumpChildren (FdtFindChild (mOffStruct, "soc", 3), 6);
      }
    }
  }

  //
  // keys139: PmicDxe's VadcConfigParse (file offset 0x1f114) refuses to go further unless
  // +0x28/+0x68/+0x70 answer for "/sw/pmic/adc/vadc/spmi-vadc@7".  Prove them here so a single
  // DEBUG line says whether the fix took, without waiting for the 0x1e3a8 crash.
  //
  {
    VOID    *Vadc;
    UINT32  ChildCount;
    UINT32  NameSizes[4];
    CHAR8   NameBuf[96];
    UINT32  SecondOff;

    Vadc = NULL;
    if (!EFI_ERROR (EfiApi_GetNode (&Vadc, "/sw/pmic/adc/vadc/spmi-vadc@7"))) {
      ChildCount = 0;
      if (!EFI_ERROR (EfiApi_GetChildCount ((UINTN)&Vadc, (UINTN)&ChildCount, 0, 0))) {
        ZeroMem (NameSizes, sizeof (NameSizes));
        ZeroMem (NameBuf, sizeof (NameBuf));
        EfiApi_GetChildNameSizes ((UINTN)&Vadc, (UINTN)NameSizes,
                                  (ChildCount < 4) ? ChildCount : 4, 0);
        EfiApi_GetChildNames ((UINTN)&Vadc, (UINTN)NameBuf, (UINTN)sizeof (NameBuf), 0);
        SecondOff = (NameSizes[0] < sizeof (NameBuf)) ? NameSizes[0] : 0;
        DEBUG ((DEBUG_ERROR,
                "[DTBEXTN] selftest vadc: children=%d first=\"%a\" second=\"%a\"\n",
                ChildCount, NameBuf, NameBuf + SecondOff));
      } else {
        DEBUG ((DEBUG_ERROR, "[DTBEXTN] selftest vadc: +0x28 child count FAILED\n"));
      }
    } else {
      DEBUG ((DEBUG_ERROR, "[DTBEXTN] selftest: vadc node NOT FOUND\n"));
    }
  }

  Status = gBS->InstallMultipleProtocolInterfaces (
                  &ImageHandle,
                  &mDtbExtnProtocolGuid,
                  &mInterface,
                  NULL
                  );
  if (EFI_ERROR (Status)) {
    DEBUG ((DEBUG_ERROR, "[DTBEXTN] install failed: %r\n", Status));
    return EFI_SUCCESS;
  }

  mInstalled = TRUE;
  DEBUG ((DEBUG_ERROR, "[DTBEXTN] protocol installed, ifc=0x%lx version=0x%lx\n",
          (UINT64)(UINTN)&mInterface, mInterface.Version));

  //
  // Also publish the tree as the FDT configuration table so anything using the standard
  // EFI_DTB_TABLE lookup finds the same tree.
  //
  Status = gBS->InstallConfigurationTable ((EFI_GUID *)&mFdtTableGuid, (VOID *)mBlob);
  DEBUG ((DEBUG_ERROR, "[DTBEXTN] fdt cfg table install: %r\n", Status));


  //
  // keys148: DWC3 / Qualcomm USB wrapper register map.  The authoritative
  // offsets come from the vendor driver (UsbfnDwc3Dxe) and from
  // xyyyds0106/ios-vermeer-lab xnu patches 0072/0073/0074:
  //   GCTL       0xC110  GSTS        0xC118  GSNPSID    0xC120
  //   GUSB2PHYCFG 0xC200 DCFG        0xC700  DCTL       0xC704
  //   DEVTEN     0xC708  DSTS        0xC70C  DALEPENA   0xC720
  // DCTL: bit31 RUN_STOP, bit30 CSFTRST.  DSTS: bit22 DEVCTRLHLT,
  // bits[2:0] speed, bits[21:18] USBLNKST.
  //
  // keys147c/keys147d used 0xC700 as DCTL and 0xC704 as DSTS, i.e. off by
  // four bytes: the RUN_STOP bit was written into DCFG (where it is
  // meaningless) and the "hlt" readback actually sampled DCTL, so the device
  // controller never left soft-disconnect.  Corrected here.
  //
  {
    UINT64  Base = 0x0A600000ULL;
    UINT32  Gen, Hs, Ss;
    UINT32  Gsnpsid, Gctl, Gsts, GUsb2PhyCfg, Dcfg, Dctl, Devten, Dsts;

    Gsnpsid     = *(volatile UINT32 *)(UINTN)(Base + 0xC120);
    Gctl        = *(volatile UINT32 *)(UINTN)(Base + 0xC110);
    Gsts        = *(volatile UINT32 *)(UINTN)(Base + 0xC118);
    GUsb2PhyCfg = *(volatile UINT32 *)(UINTN)(Base + 0xC200);
    Dcfg        = *(volatile UINT32 *)(UINTN)(Base + 0xC700);
    Dctl        = *(volatile UINT32 *)(UINTN)(Base + 0xC704);
    Devten      = *(volatile UINT32 *)(UINTN)(Base + 0xC708);
    Dsts        = *(volatile UINT32 *)(UINTN)(Base + 0xC70C);
    Gen         = *(volatile UINT32 *)(UINTN)(0x0A6F8800ULL + 0x08);
    Hs          = *(volatile UINT32 *)(UINTN)(0x0A6F8800ULL + 0x10);
    Ss          = *(volatile UINT32 *)(UINTN)(0x0A6F8800ULL + 0x30);

    DEBUG ((DEBUG_ERROR,
            "[VBUS] before: GSNPSID=%08x GCTL=%08x GSTS=%08x GUSB2PHYCFG=%08x DCFG=%08x DCTL=%08x DEVTEN=%08x DSTS=%08x\n",
            Gsnpsid, Gctl, Gsts, GUsb2PhyCfg, Dcfg, Dctl, Devten, Dsts));
    DEBUG ((DEBUG_ERROR,
            "[VBUS] scratch: GEN=%08x HS=%08x SS=%08x\n", Gen, Hs, Ss));

    //
    // Qualcomm QSCRATCH VBUS-valid override (same as Linux dwc3-qcom
    // dwc3_qcom_vbus_override_enable / xnu 0074):
    //   HS_PHY_CTRL bit20 UTMI_OTG_VBUS_VALID, bit28 SW_SESSVLD_SEL
    //   SS_PHY_CTRL bit24 LANE0_PWR_PRESENT
    //
    *(volatile UINT32 *)(UINTN)(0x0A6F8800ULL + 0x10) = Hs | (1U << 20) | (1U << 28);
    *(volatile UINT32 *)(UINTN)(0x0A6F8800ULL + 0x30) = Ss | (1U << 24);
    MemoryFence ();

    //
    // NOTE (keys148): we deliberately do *not* touch GUSB2PHYCFG or DCTL here.
    // The vendor UsbConfigDxe/UsbfnDwc3Dxe own the core bring-up (soft reset,
    // event buffer, EP0 setup, RUN_STOP); forcing RUN_STOP from this early
    // APRIORI position could race the vendor init.  The late "release halt"
    // attempt runs from VermeerLogDiskDxe after the whole USB stack is loaded.
    //
    Hs          = *(volatile UINT32 *)(UINTN)(0x0A6F8800ULL + 0x10);
    Ss          = *(volatile UINT32 *)(UINTN)(0x0A6F8800ULL + 0x30);
    GUsb2PhyCfg = *(volatile UINT32 *)(UINTN)(Base + 0xC200);
    Dcfg        = *(volatile UINT32 *)(UINTN)(Base + 0xC700);
    Dctl        = *(volatile UINT32 *)(UINTN)(Base + 0xC704);
    Dsts        = *(volatile UINT32 *)(UINTN)(Base + 0xC70C);

    DEBUG ((DEBUG_ERROR,
            "[VBUS] after : HS=%08x SS=%08x GUSB2PHYCFG=%08x DCFG=%08x DCTL=%08x DSTS=%08x\n",
            Hs, Ss, GUsb2PhyCfg, Dcfg, Dctl, Dsts));
    DEBUG ((DEBUG_ERROR,
            "[VBUS] dec   : run_stop=%d csfrst=%d phy_susphy=%d phy_enblslpm=%d hlt22=%d speed=%d linkst=%d\n",
            (Dctl >> 31) & 1, (Dctl >> 30) & 1, (GUsb2PhyCfg >> 6) & 1,
            (GUsb2PhyCfg >> 8) & 1, (Dsts >> 22) & 1, Dsts & 7,
            (Dsts >> 18) & 0xF));
  }

  //
  // keys158: EARLY device-mode bring-up with the device EVENT path disabled
  // on purpose.
  //
  // Hardware evidence (keys157, lead m03692): after the core was started here
  // the host began enumerating (Windows reported VID_0000&PID_0002, "device
  // descriptor request failed") and the phone then reset.  At that moment
  // DEVTEN was 0x00001277 -- a stale non-zero value we never wrote -- while
  // nothing had promised that GEVNTADR pointed at a valid, 4 KiB aligned
  // event buffer.  An enabled device event with a bad event-buffer address
  // makes the controller DMA to an invalid address (0x0) -> AXI decode error
  // -> SError -> reset.  So: clear DEVTEN and the whole event-buffer setup
  // BEFORE pulling the core out of halt, verify the clear by reading back,
  // and only then do PHYCFG / RUN_STOP.  The vendor UsbfnDwc3Dxe reprograms
  // DEVTEN + GEVNTADR itself during its own Start(); it runs after this
  // driver (APRIORI 4 < UsbfnDwc3Dxe).
  //
  // Sequence (keys158):
  //   read + print DEVTEN / GEVNTADRLO / GEVNTADRHI / GEVNTSIZ / GEVNTCOUNT
  //   DEVTEN = 0 ; GEVNTADRLO = 0 ; GEVNTADRHI = 0 ; GEVNTSIZ = 0 ;
  //   GEVNTCOUNT = <read value> (write-to-clear)
  //   read back + print (verification that events are off)
  //   GUSB2PHYCFG &= ~(SUSPHY | ENBLSLPM | PHYSOFTRST)
  //   DCTL        |= RUN_STOP
  //   poll DSTS.DEVCTRLHLT == 0 (300 ms budget, 1 ms sleeps)
  //
  {
    UINT64  UsbBase = 0x0A600000ULL;
    UINT32  UsbGctl, UsbPhyCfg, UsbDctl, UsbDevten, UsbDsts;
    UINT32  UsbAddrLo, UsbAddrHi, UsbSiz, UsbCount;
    UINT32  UsbAlt710, UsbAlt714, UsbAlt718, UsbAlt71C;
    UINT32  UsbPoll;

    UsbGctl   = *(volatile UINT32 *)(UINTN)(UsbBase + 0xC110);
    UsbPhyCfg = *(volatile UINT32 *)(UINTN)(UsbBase + 0xC200);
    UsbDctl   = *(volatile UINT32 *)(UINTN)(UsbBase + 0xC704);
    UsbDevten = *(volatile UINT32 *)(UINTN)(UsbBase + 0xC708);
    UsbDsts   = *(volatile UINT32 *)(UINTN)(UsbBase + 0xC70C);
    UsbAddrLo = *(volatile UINT32 *)(UINTN)(UsbBase + 0xC400);
    UsbAddrHi = *(volatile UINT32 *)(UINTN)(UsbBase + 0xC404);
    UsbSiz    = *(volatile UINT32 *)(UINTN)(UsbBase + 0xC408);
    UsbCount  = *(volatile UINT32 *)(UINTN)(UsbBase + 0xC40C);
    UsbAlt710 = *(volatile UINT32 *)(UINTN)(UsbBase + 0xC710);
    UsbAlt714 = *(volatile UINT32 *)(UINTN)(UsbBase + 0xC714);
    UsbAlt718 = *(volatile UINT32 *)(UINTN)(UsbBase + 0xC718);
    UsbAlt71C = *(volatile UINT32 *)(UINTN)(UsbBase + 0xC71C);

    DEBUG ((DEBUG_ERROR,
            "[USB158] pre : GCTL=%08x PHYCFG=%08x DCTL=%08x DEVTEN=%08x DSTS=%08x\n",
            UsbGctl, UsbPhyCfg, UsbDctl, UsbDevten, UsbDsts));
    DEBUG ((DEBUG_ERROR,
            "[USB158] evt pre : ADDRLO=%08x ADDRHI=%08x SIZ=%08x COUNT=%08x\n",
            UsbAddrLo, UsbAddrHi, UsbSiz, UsbCount));
    DEBUG ((DEBUG_ERROR,
            "[USB158] alt pre : 710=%08x 714=%08x 718=%08x 71C=%08x\n",
            UsbAlt710, UsbAlt714, UsbAlt718, UsbAlt71C));

    //
    // 1) Kill the device event path before the host can talk to us.
    //
    *(volatile UINT32 *)(UINTN)(UsbBase + 0xC708) = 0;      // DEVTEN
    *(volatile UINT32 *)(UINTN)(UsbBase + 0xC404) = 0;      // GEVNTADRHI
    *(volatile UINT32 *)(UINTN)(UsbBase + 0xC400) = 0;      // GEVNTADRLO
    *(volatile UINT32 *)(UINTN)(UsbBase + 0xC408) = 0;      // GEVNTSIZ
    *(volatile UINT32 *)(UINTN)(UsbBase + 0xC40C) = UsbCount; // GEVNTCOUNT (write-to-clear)
    MemoryFence ();

    UsbDevten = *(volatile UINT32 *)(UINTN)(UsbBase + 0xC708);
    UsbAddrLo = *(volatile UINT32 *)(UINTN)(UsbBase + 0xC400);
    UsbAddrHi = *(volatile UINT32 *)(UINTN)(UsbBase + 0xC404);
    UsbSiz    = *(volatile UINT32 *)(UINTN)(UsbBase + 0xC408);
    UsbCount  = *(volatile UINT32 *)(UINTN)(UsbBase + 0xC40C);
    DEBUG ((DEBUG_ERROR,
            "[USB158] evt off : DEVTEN=%08x ADDRLO=%08x ADDRHI=%08x SIZ=%08x COUNT=%08x\n",
            UsbDevten, UsbAddrLo, UsbAddrHi, UsbSiz, UsbCount));

    //
    // 2) Only now pull the core out of halt.
    //
    if ((UsbDctl & (1U << 31)) == 0) {
      UsbPhyCfg &= ~((1U << 6) | (1U << 8) | (1U << 31));
      *(volatile UINT32 *)(UINTN)(UsbBase + 0xC200) = UsbPhyCfg;
      MemoryFence ();
      *(volatile UINT32 *)(UINTN)(UsbBase + 0xC704) = UsbDctl | (1U << 31);
      MemoryFence ();
      for (UsbPoll = 0; UsbPoll < 300; UsbPoll++) {
        UsbDsts = *(volatile UINT32 *)(UINTN)(UsbBase + 0xC70C);
        if ((UsbDsts & (1U << 22)) == 0) {
          break;
        }
        gBS->Stall (1000);
      }
      UsbPhyCfg = *(volatile UINT32 *)(UINTN)(UsbBase + 0xC200);
      UsbDctl   = *(volatile UINT32 *)(UINTN)(UsbBase + 0xC704);
      UsbDsts   = *(volatile UINT32 *)(UINTN)(UsbBase + 0xC70C);
      UsbDevten = *(volatile UINT32 *)(UINTN)(UsbBase + 0xC708);
      UsbAddrLo = *(volatile UINT32 *)(UINTN)(UsbBase + 0xC400);
      UsbSiz    = *(volatile UINT32 *)(UINTN)(UsbBase + 0xC408);
      DEBUG ((DEBUG_ERROR,
              "[USB158] early run : polls=%u PHYCFG=%08x DCTL=%08x DSTS=%08x hlt22=%d run=%d "
              "DEVTEN=%08x ADDRLO=%08x SIZ=%08x\n",
              UsbPoll, UsbPhyCfg, UsbDctl, UsbDsts, (UsbDsts >> 22) & 1, (UsbDctl >> 31) & 1,
              UsbDevten, UsbAddrLo, UsbSiz));
    } else {
      DEBUG ((DEBUG_ERROR,
              "[USB158] early run : already running (DCTL bit31=1), events kept off DEVTEN=%08x\n",
              UsbDevten));
    }
  }

  //
  // keys168: console landmark so a later black screen cannot hide how far the
  // provider got (20 ms settle guarantees it has reached the framebuffer).
  //
  if ((gST != NULL) && (gST->ConOut != NULL)) {
    gST->ConOut->OutputString (gST->ConOut, L"\r\n[168] provider done\r\n");
    gBS->Stall (20000);
  }

  return EFI_SUCCESS;
}
