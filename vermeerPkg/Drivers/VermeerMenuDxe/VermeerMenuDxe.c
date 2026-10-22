/** @file
  VermeerMenuDxe - late-stage interactive menu (keys101).

  Runs at the very end of the APRIORI list, where ConSplitterDxe has already
  published Simple Text Input, so volume keys work. The early probe driver
  stays diagnostic-only.

  Copyright (c) 2026. All rights reserved.
**/

#include <Uefi.h>
#include <Protocol/SimpleTextIn.h>
#include <Protocol/GraphicsOutput.h>
#include <Protocol/BlockIo.h>   // keys124: block device counter  // keys112: GOP probe
#include <Library/UefiLib.h>
#include <Library/BaseLib.h>
#include <Library/BaseMemoryLib.h>
#include <Library/DebugLib.h>
#include <Library/DxeServicesLib.h>   // keys115
#include <Library/MemoryAllocationLib.h>  // keys115
#include <Library/UefiBootServicesTableLib.h>
#include <Library/UefiRuntimeServicesTableLib.h>
#include <Library/UefiDriverEntryPoint.h>
#include <Library/PrintLib.h>
#include <Library/MemoryAllocationLib.h>

STATIC EFI_SIMPLE_TEXT_OUTPUT_PROTOCOL  *mOut;
STATIC EFI_SIMPLE_TEXT_INPUT_PROTOCOL   *mIn;


STATIC BOOLEAN  mGopPresent = FALSE;   // keys113
STATIC UINT32   mGopW = 0;
STATIC UINT32   mGopH = 0;
STATIC BOOLEAN  mGopProbed  = FALSE;


STATIC
VOID
Say (
  CONST CHAR16  *Text
  );

STATIC EFI_GRAPHICS_OUTPUT_PROTOCOL   *mGuiGop;      // keys117fwd

STATIC
VOID
WaitAnyKey (
  VOID
  )
{
  EFI_INPUT_KEY Key;
  UINTN         I;
  UINTN         Tries = 0;
  EFI_HANDLE   *Hbuf  = NULL;
  UINTN         Hcnt  = 0;
  EFI_SIMPLE_TEXT_INPUT_PROTOCOL *Ins[8];
  UINTN         InsCount = 0;

  if (!EFI_ERROR (gBS->LocateHandleBuffer (ByProtocol, &gEfiSimpleTextInProtocolGuid, NULL, &Hcnt, &Hbuf))) {
    for (I = 0; I < Hcnt && InsCount < 8; I++) {
      VOID *Ifc = NULL;
      if (!EFI_ERROR (gBS->HandleProtocol (Hbuf[I], &gEfiSimpleTextInProtocolGuid, &Ifc)) && Ifc != NULL) {
        Ins[InsCount++] = (EFI_SIMPLE_TEXT_INPUT_PROTOCOL *)Ifc;
      }
    }
    gBS->FreePool (Hbuf);
  }
  while (Tries++ < 300) {            // up to ~6 s
    for (I = 0; I < InsCount; I++) {
      if (!EFI_ERROR (Ins[I]->ReadKeyStroke (Ins[I], &Key))) {
        return;
      }
    }
    gBS->Stall (20000);
  }
}

STATIC
VOID
GuiMenu (
  VOID
  );

STATIC CONST EFI_GUID mSimpleFbGuid = { 0xDCFD1E6D, 0x788D, 0x4FFC, { 0x8E, 0x1B, 0xCA, 0x2F, 0x75, 0x65, 0x1A, 0x92 } };  // keys115

STATIC BOOLEAN mFbLoadTried = FALSE;   // keys116


STATIC
VOID
FillRect (
  IN EFI_GRAPHICS_OUTPUT_PROTOCOL  *Gop,
  IN UINTN                          X,
  IN UINTN                          Y,
  IN UINTN                          W,
  IN UINTN                          H,
  IN UINT32                         Rgb
  )
{
  EFI_GRAPHICS_OUTPUT_BLT_PIXEL  Pixel;
  Pixel.Blue     = (UINT8)(Rgb & 0xFF);
  Pixel.Green    = (UINT8)((Rgb >> 8) & 0xFF);
  Pixel.Red      = (UINT8)((Rgb >> 16) & 0xFF);
  Pixel.Reserved = 0;
  Gop->Blt (Gop, &Pixel, EfiBltVideoFill, 0, 0, X, Y, W, H, 0);
}

STATIC
VOID
DrawBanner (
  VOID
  )
{
  EFI_GRAPHICS_OUTPUT_PROTOCOL  *Gop = NULL;
  CHAR16                         Line3[128];

  if (EFI_ERROR (gBS->LocateProtocol (&gEfiGraphicsOutputProtocolGuid, NULL, (VOID **)&Gop)) || Gop == NULL) {
    return;
  }
  // keys116: prove real pixel output (banner + right edge bar)
  FillRect (Gop, 0, 0, 1440, 140, 0x00204080);
  FillRect (Gop, 0, 140, 1440, 6, 0x0000C0FF);
  FillRect (Gop, 1400, 0, 40, 3200, 0x00404040);
  UnicodeSPrint (Line3, sizeof (Line3), L"  [UI] GFX banner drawn 1440x3200\r\n");
  Say (Line3);
}

STATIC
VOID
ForceLoadSimpleFb (
  VOID
  )
{
  //
  // keys168: SimpleFb LoadImage/StartImage intentionally disabled (text UI only).
  //
  if (mFbLoadTried) {
    return;
  }
  mFbLoadTried = TRUE;
  Say (L"  [UI167] SimpleFb load disabled (keys168)");
}

STATIC
VOID
ProbeGop (
  VOID
  )
{
  EFI_GRAPHICS_OUTPUT_PROTOCOL  *Gop = NULL;
  if (mGopProbed) {
    return;
  }
  mGopProbed = TRUE;
  if (!EFI_ERROR (gBS->LocateProtocol (&gEfiGraphicsOutputProtocolGuid, NULL, (VOID **)&Gop)) &&
      Gop != NULL && Gop->Mode != NULL && Gop->Mode->Info != NULL) {
    mGopPresent = TRUE;
    mGopW       = (UINT32)Gop->Mode->Info->HorizontalResolution;
    mGopH       = (UINT32)Gop->Mode->Info->VerticalResolution;
  }
}

STATIC
VOID
Say (
  IN CONST CHAR16  *Text
  )
{
  CHAR8  Ascii[160];
  UINTN  Index;

  //
  // Never depend on the console alone: the framebuffer serial port always works.
  //
  for (Index = 0; (Index < sizeof (Ascii) - 1) && (Text[Index] != 0); Index++) {
    Ascii[Index] = (CHAR8)(Text[Index] & 0xFF);
  }

  Ascii[Index] = 0;
  DEBUG ((DEBUG_ERROR, "[MENU] %a\n", Ascii));

  if (mOut != NULL) {
    mOut->OutputString (mOut, (CHAR16 *)Text);
    mOut->OutputString (mOut, L"\r\n");
  }
}

STATIC VOID
DoReboot (
  VOID
  )
{
  Say (L"  [UI] rebooting...");
  gRT->ResetSystem (EfiResetCold, EFI_SUCCESS, 0, NULL);
}

STATIC VOID
DoShutdown (
  VOID
  )
{
  Say (L"  [UI] powering off...");
  gRT->ResetSystem (EfiResetShutdown, EFI_SUCCESS, 0, NULL);
}

STATIC VOID
ShowInfo (
  VOID
  )
{
  UINTN                      Size;
  UINTN                      Key;
  UINTN                      DescSize;
  UINT32                     DescVer;
  EFI_MEMORY_DESCRIPTOR      *Map;
  EFI_STATUS                 Status;
  CHAR16                     Line[128];

  Size     = 0;
  DescSize = 0;
  DescVer  = 0;
  Map      = NULL;

  Status = gBS->GetMemoryMap (&Size, Map, &Key, &DescSize, &DescVer);
  if (Status == EFI_BUFFER_TOO_SMALL) {
    Size += 4 * DescSize;
    Map   = AllocatePool (Size);
    if (Map != NULL) {
      Status = gBS->GetMemoryMap (&Size, Map, &Key, &DescSize, &DescVer);
    }
  }

  Say (L"  [UI] ---- device information ----");
  UnicodeSPrint (Line, sizeof (Line), L"  [UI] memory map: %d bytes, %d descriptors",
                 Size, (DescSize == 0) ? 0 : (Size / DescSize));
  Say (Line);
  UnicodeSPrint (Line, sizeof (Line), L"  [UI] image handle=0x%016lx", (UINT64)(UINTN)gImageHandle);
  Say (Line);
  {  // keys112: report GOP (SimpleFbDxe) availability
    EFI_GRAPHICS_OUTPUT_PROTOCOL  *Gop = NULL;
    EFI_STATUS                     Gst;
    Gst = gBS->LocateProtocol (&gEfiGraphicsOutputProtocolGuid, NULL, (VOID **)&Gop);
    if (!EFI_ERROR (Gst) && Gop != NULL && Gop->Mode != NULL && Gop->Mode->Info != NULL) {
      UnicodeSPrint (Line, sizeof (Line), L"  [UI] GOP=yes %ux%u\r\n",
                     (UINT32)Gop->Mode->Info->HorizontalResolution,
                     (UINT32)Gop->Mode->Info->VerticalResolution);
    } else {
      UnicodeSPrint (Line, sizeof (Line), L"  [UI] GOP=no (%r)\r\n", Gst);
    }
    Say (Line);
  }
  UnicodeSPrint (Line, sizeof (Line), L"  [UI] ConIn=%s ConOut=%s",
                 (mIn == NULL) ? L"null" : L"ok", (mOut == NULL) ? L"null" : L"ok");
  Say (Line);
  Say (L"  [UI] ------------------------------");

  if (Map != NULL) {
    FreePool (Map);
  }
}

STATIC
VOID
DrawMenu (
  IN UINTN  Selected
  )
{
  STATIC CONST CHAR16  *Items[] = {
    L"1. Boot Linux (UFS)",
    L"2. Boot UniXNU",
    L"3. Device information",
    L"4. Reboot",
    L"5. Power off"
  };
  UINTN                Index;
  CHAR16               Line[128];

  Say (L"");
  Say (L"  ================================");
  Say (L"  [UI] ==== Vermeer UEFI menu ====");
  for (Index = 0; Index < sizeof (Items) / sizeof (Items[0]); Index++) {
    UnicodeSPrint (Line, sizeof (Line), L"  [UI] %s %s",
                   (Index == Selected) ? L">" : L" ", Items[Index]);
    Say (Line);
  }

  ForceLoadSimpleFb ();  // keys115
  ProbeGop ();
  if (mGopPresent) {
    mGuiGop = NULL;
    gBS->LocateProtocol (&gEfiGraphicsOutputProtocolGuid, NULL, (VOID **)&mGuiGop);
    if (mGuiGop != NULL) {
      GuiMenu ();   // keys117: never returns
    }
  }
  {
    CHAR16  GopLine[96];
    if (mGopPresent) {
      UnicodeSPrint (GopLine, sizeof (GopLine), L"  [UI] GOP=yes %ux%u\r\n", mGopW, mGopH);
      DrawBanner ();   // keys116
    } else {
      UnicodeSPrint (GopLine, sizeof (GopLine), L"  [UI] GOP=no\r\n");
    }
    Say (GopLine);
  }
  // keys113
  Say (L"  [UI]  VOL-UP / VOL-DOWN to move, idle 3 s = act");
  Say (L"  ================================");
}

STATIC
VOID
RunMenu (
  VOID
  )
{
  UINTN         Selected;
  UINTN         IdleCount;
  BOOLEAN       KeySeen;
  EFI_INPUT_KEY Key;
  EFI_STATUS    Status;
  CHAR16        Line[128];
  EFI_SIMPLE_TEXT_INPUT_PROTOCOL  *InList[8];
  UINTN                            InCount;
  UINTN                            HandleIdx;
  EFI_HANDLE                      *Handles;
  UINTN                            HandleCount;
  UINTN                            Index;

  Handles     = NULL;
  HandleCount = 0;
  InCount     = 0;

  if ((gST->ConIn != NULL) && (InCount < 8)) {
    InList[InCount++] = gST->ConIn;
  }

  Status = gBS->LocateHandleBuffer (ByProtocol, &gEfiSimpleTextInProtocolGuid, NULL, &HandleCount, &Handles);
  if (!EFI_ERROR (Status)) {
    for (Index = 0; (Index < HandleCount) && (InCount < 8); Index++) {
      EFI_SIMPLE_TEXT_INPUT_PROTOCOL  *Ifc = NULL;
      if (!EFI_ERROR (gBS->HandleProtocol (Handles[Index], &gEfiSimpleTextInProtocolGuid, (VOID **)&Ifc)) && (Ifc != NULL)) {
        InList[InCount++] = Ifc;
      }
    }
    FreePool (Handles);
  }

  mIn = (InCount > 0) ? InList[0] : NULL;
  UnicodeSPrint (Line, sizeof (Line), L"  [MENU105] SimpleTextIn instances: %d", InCount);
  Say (Line);

  Selected  = 1;
  IdleCount = 0;
  KeySeen   = FALSE;
  DrawMenu (Selected);

  for (;;) {
    Status = EFI_NOT_READY;
    for (HandleIdx = 0; HandleIdx < InCount; HandleIdx++) {
      Status = InList[HandleIdx]->ReadKeyStroke (InList[HandleIdx], &Key);
      if (!EFI_ERROR (Status)) {
        break;
      }
    }


    if (!EFI_ERROR (Status)) {
      IdleCount = 0;
      KeySeen   = TRUE;
      UnicodeSPrint (Line, sizeof (Line), L"  [UI] key #%d: ScanCode=0x%04x Unicode=0x%04x", HandleIdx, Key.ScanCode, Key.UnicodeChar);
      Say (Line);
      if (Key.ScanCode == 0x01) {
        Selected = (Selected == 0) ? 4 : Selected - 1;
        DrawMenu (Selected);
      } else if (Key.ScanCode == 0x02) {
        Selected = (Selected == 4) ? 0 : Selected + 1;
        DrawMenu (Selected);
      } else {
        Say (L"  [UI] (other key ignored)");
      }
    } else {
      gBS->Stall (100 * 1000);
      if (!KeySeen) {
        continue;
      }

      IdleCount++;
      if (IdleCount >= 30) {
        IdleCount = 0;
        switch (Selected) {
          case 0:
            Say (L"  [UI] Boot Linux: no block device yet (UFS not ready)");
            break;
          case 1:
            Say (L"  [UI] Boot UniXNU: \\EFI\\UniXNU\\unixnu.efi not found (no file system)");
            break;
          case 2:
            ShowInfo ();
            break;
          case 3:
            DoReboot ();
            break;
          case 4:
            DoShutdown ();
            break;
          default:
            break;
        }
      }
    }
  }
}

// auto-generated 8x16 ASCII font (32..126), rows top->bottom, MSB = leftmost pixel
STATIC CONST UINT8 mFont8x16[95][16] = {
  { 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 },  // 32
  { 0x00, 0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x00, 0x18, 0x18, 0x00, 0x00, 0x00, 0x00, 0x00 },  // 33
  { 0x00, 0x6C, 0x6C, 0x6C, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 },  // 34
  { 0x00, 0x00, 0x24, 0x24, 0xFE, 0x24, 0x48, 0xFE, 0x48, 0x48, 0x48, 0x00, 0x00, 0x00, 0x00, 0x00 },  // 35
  { 0x00, 0x08, 0x3C, 0x48, 0x50, 0x70, 0x1C, 0x16, 0x12, 0x12, 0x7C, 0x10, 0x10, 0x00, 0x00, 0x00 },  // 36
  { 0x00, 0x62, 0x94, 0x9C, 0x68, 0x10, 0x10, 0x26, 0x69, 0x49, 0x86, 0x00, 0x00, 0x00, 0x00, 0x00 },  // 37
  { 0x00, 0x30, 0x48, 0x48, 0x78, 0x30, 0x74, 0x94, 0x8C, 0x8C, 0x76, 0x00, 0x00, 0x00, 0x00, 0x00 },  // 38
  { 0x00, 0x18, 0x18, 0x18, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 },  // 39
  { 0x00, 0x04, 0x08, 0x10, 0x10, 0x20, 0x20, 0x20, 0x20, 0x20, 0x10, 0x10, 0x08, 0x04, 0x00, 0x00 },  // 40
  { 0x00, 0x40, 0x20, 0x10, 0x10, 0x08, 0x08, 0x08, 0x08, 0x08, 0x10, 0x10, 0x20, 0x40, 0x00, 0x00 },  // 41
  { 0x00, 0x08, 0x2A, 0x1C, 0x1C, 0x2A, 0x08, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 },  // 42
  { 0x00, 0x00, 0x00, 0x00, 0x10, 0x10, 0x10, 0xFE, 0x10, 0x10, 0x10, 0x00, 0x00, 0x00, 0x00, 0x00 },  // 43
  { 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x18, 0x18, 0x08, 0x30, 0x00, 0x00, 0x00 },  // 44
  { 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x3C, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 },  // 45
  { 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x18, 0x18, 0x00, 0x00, 0x00, 0x00, 0x00 },  // 46
  { 0x00, 0x02, 0x04, 0x04, 0x0C, 0x08, 0x18, 0x10, 0x10, 0x20, 0x20, 0x40, 0x00, 0x00, 0x00, 0x00 },  // 47
  { 0x00, 0x00, 0x3C, 0x24, 0x42, 0x46, 0x5A, 0x62, 0x42, 0x24, 0x3C, 0x00, 0x00, 0x00, 0x00, 0x00 },  // 48
  { 0x00, 0x00, 0x08, 0x18, 0x28, 0x08, 0x08, 0x08, 0x08, 0x08, 0x3E, 0x00, 0x00, 0x00, 0x00, 0x00 },  // 49
  { 0x00, 0x00, 0x3C, 0x42, 0x02, 0x02, 0x04, 0x0C, 0x18, 0x30, 0x7E, 0x00, 0x00, 0x00, 0x00, 0x00 },  // 50
  { 0x00, 0x00, 0x78, 0x04, 0x04, 0x04, 0x38, 0x04, 0x04, 0x04, 0x78, 0x00, 0x00, 0x00, 0x00, 0x00 },  // 51
  { 0x00, 0x00, 0x18, 0x18, 0x28, 0x68, 0x48, 0x88, 0xFE, 0x08, 0x08, 0x00, 0x00, 0x00, 0x00, 0x00 },  // 52
  { 0x00, 0x00, 0x7C, 0x40, 0x40, 0x40, 0x78, 0x04, 0x04, 0x0C, 0x78, 0x00, 0x00, 0x00, 0x00, 0x00 },  // 53
  { 0x00, 0x00, 0x1C, 0x20, 0x40, 0x5C, 0x62, 0x42, 0x42, 0x66, 0x3C, 0x00, 0x00, 0x00, 0x00, 0x00 },  // 54
  { 0x00, 0x00, 0x7E, 0x02, 0x04, 0x04, 0x08, 0x08, 0x10, 0x10, 0x30, 0x00, 0x00, 0x00, 0x00, 0x00 },  // 55
  { 0x00, 0x00, 0x3C, 0x42, 0x42, 0x66, 0x18, 0x66, 0x42, 0x42, 0x3C, 0x00, 0x00, 0x00, 0x00, 0x00 },  // 56
  { 0x00, 0x00, 0x3C, 0x66, 0x42, 0x42, 0x46, 0x3A, 0x02, 0x04, 0x38, 0x00, 0x00, 0x00, 0x00, 0x00 },  // 57
  { 0x00, 0x00, 0x00, 0x00, 0x18, 0x18, 0x00, 0x00, 0x00, 0x18, 0x18, 0x00, 0x00, 0x00, 0x00, 0x00 },  // 58
  { 0x00, 0x00, 0x00, 0x00, 0x18, 0x18, 0x00, 0x00, 0x00, 0x18, 0x18, 0x08, 0x30, 0x00, 0x00, 0x00 },  // 59
  { 0x00, 0x00, 0x00, 0x04, 0x08, 0x10, 0x20, 0x60, 0x10, 0x08, 0x04, 0x00, 0x00, 0x00, 0x00, 0x00 },  // 60
  { 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x7E, 0x00, 0x7E, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 },  // 61
  { 0x00, 0x00, 0x00, 0x40, 0x20, 0x10, 0x08, 0x0C, 0x10, 0x20, 0x40, 0x00, 0x00, 0x00, 0x00, 0x00 },  // 62
  { 0x00, 0x30, 0x08, 0x04, 0x04, 0x04, 0x38, 0x20, 0x00, 0x30, 0x30, 0x00, 0x00, 0x00, 0x00, 0x00 },  // 63
  { 0x00, 0x1C, 0x22, 0x41, 0x41, 0x9D, 0xB5, 0xA5, 0xA5, 0xA5, 0xBE, 0x80, 0x44, 0x38, 0x00, 0x00 },  // 64
  { 0x00, 0x00, 0x18, 0x28, 0x28, 0x6C, 0x44, 0x44, 0xFE, 0x82, 0x82, 0x00, 0x00, 0x00, 0x00, 0x00 },  // 65
  { 0x00, 0x00, 0x7C, 0x42, 0x42, 0x46, 0x7C, 0x42, 0x42, 0x42, 0x7C, 0x00, 0x00, 0x00, 0x00, 0x00 },  // 66
  { 0x00, 0x00, 0x1C, 0x22, 0x40, 0x40, 0x40, 0x40, 0x40, 0x22, 0x1C, 0x00, 0x00, 0x00, 0x00, 0x00 },  // 67
  { 0x00, 0x00, 0x78, 0x44, 0x42, 0x42, 0x42, 0x42, 0x42, 0x44, 0x78, 0x00, 0x00, 0x00, 0x00, 0x00 },  // 68
  { 0x00, 0x00, 0x7C, 0x40, 0x40, 0x40, 0x7C, 0x40, 0x40, 0x40, 0x7C, 0x00, 0x00, 0x00, 0x00, 0x00 },  // 69
  { 0x00, 0x00, 0x7C, 0x40, 0x40, 0x40, 0x7C, 0x40, 0x40, 0x40, 0x40, 0x00, 0x00, 0x00, 0x00, 0x00 },  // 70
  { 0x00, 0x00, 0x38, 0x44, 0x80, 0x80, 0x9C, 0x84, 0x84, 0x44, 0x3C, 0x00, 0x00, 0x00, 0x00, 0x00 },  // 71
  { 0x00, 0x00, 0x42, 0x42, 0x42, 0x42, 0x7E, 0x42, 0x42, 0x42, 0x42, 0x00, 0x00, 0x00, 0x00, 0x00 },  // 72
  { 0x00, 0x00, 0x7C, 0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x7C, 0x00, 0x00, 0x00, 0x00, 0x00 },  // 73
  { 0x00, 0x00, 0x7C, 0x04, 0x04, 0x04, 0x04, 0x04, 0x04, 0x44, 0x38, 0x00, 0x00, 0x00, 0x00, 0x00 },  // 74
  { 0x00, 0x00, 0x42, 0x44, 0x48, 0x50, 0x60, 0x50, 0x48, 0x44, 0x42, 0x00, 0x00, 0x00, 0x00, 0x00 },  // 75
  { 0x00, 0x00, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x20, 0x3E, 0x00, 0x00, 0x00, 0x00, 0x00 },  // 76
  { 0x00, 0x00, 0x26, 0x66, 0x5A, 0x5A, 0x5A, 0x52, 0x42, 0x42, 0x42, 0x00, 0x00, 0x00, 0x00, 0x00 },  // 77
  { 0x00, 0x00, 0x62, 0x62, 0x52, 0x52, 0x52, 0x4A, 0x4A, 0x46, 0x46, 0x00, 0x00, 0x00, 0x00, 0x00 },  // 78
  { 0x00, 0x00, 0x38, 0x44, 0x82, 0x82, 0x82, 0x82, 0x82, 0x44, 0x38, 0x00, 0x00, 0x00, 0x00, 0x00 },  // 79
  { 0x00, 0x00, 0x7C, 0x46, 0x42, 0x42, 0x46, 0x78, 0x40, 0x40, 0x40, 0x00, 0x00, 0x00, 0x00, 0x00 },  // 80
  { 0x00, 0x00, 0x38, 0x44, 0x82, 0x82, 0x82, 0x82, 0x82, 0x44, 0x78, 0x10, 0x0E, 0x00, 0x00, 0x00 },  // 81
  { 0x00, 0x00, 0x78, 0x44, 0x44, 0x44, 0x78, 0x48, 0x4C, 0x44, 0x46, 0x00, 0x00, 0x00, 0x00, 0x00 },  // 82
  { 0x00, 0x00, 0x3C, 0x40, 0x40, 0x60, 0x1C, 0x06, 0x02, 0x02, 0x7C, 0x00, 0x00, 0x00, 0x00, 0x00 },  // 83
  { 0x00, 0x00, 0xFE, 0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x00, 0x00, 0x00, 0x00, 0x00 },  // 84
  { 0x00, 0x00, 0x42, 0x42, 0x42, 0x42, 0x42, 0x42, 0x42, 0x46, 0x3C, 0x00, 0x00, 0x00, 0x00, 0x00 },  // 85
  { 0x00, 0x00, 0x41, 0x41, 0x63, 0x22, 0x22, 0x36, 0x14, 0x14, 0x18, 0x00, 0x00, 0x00, 0x00, 0x00 },  // 86
  { 0x00, 0x00, 0x41, 0x41, 0x41, 0x69, 0x6B, 0x2A, 0x3A, 0x36, 0x36, 0x00, 0x00, 0x00, 0x00, 0x00 },  // 87
  { 0x00, 0x00, 0xC6, 0x64, 0x28, 0x18, 0x18, 0x38, 0x24, 0x46, 0xC3, 0x00, 0x00, 0x00, 0x00, 0x00 },  // 88
  { 0x00, 0x00, 0x82, 0x44, 0x44, 0x28, 0x28, 0x10, 0x10, 0x10, 0x10, 0x00, 0x00, 0x00, 0x00, 0x00 },  // 89
  { 0x00, 0x00, 0x7E, 0x04, 0x04, 0x08, 0x18, 0x10, 0x20, 0x20, 0x7E, 0x00, 0x00, 0x00, 0x00, 0x00 },  // 90
  { 0x00, 0x1C, 0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x1C, 0x00, 0x00 },  // 91
  { 0x00, 0x40, 0x20, 0x20, 0x10, 0x10, 0x18, 0x08, 0x0C, 0x04, 0x04, 0x02, 0x00, 0x00, 0x00, 0x00 },  // 92
  { 0x00, 0x38, 0x08, 0x08, 0x08, 0x08, 0x08, 0x08, 0x08, 0x08, 0x08, 0x08, 0x08, 0x38, 0x00, 0x00 },  // 93
  { 0x00, 0x00, 0x10, 0x28, 0x44, 0x44, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 },  // 94
  { 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xFF, 0x00, 0x00 },  // 95
  { 0x00, 0x60, 0x30, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 },  // 96
  { 0x00, 0x00, 0x00, 0x00, 0x18, 0x24, 0x04, 0x3C, 0x44, 0x4C, 0x3C, 0x00, 0x00, 0x00, 0x00, 0x00 },  // 97
  { 0x00, 0x40, 0x40, 0x40, 0x5C, 0x66, 0x42, 0x42, 0x42, 0x44, 0x78, 0x00, 0x00, 0x00, 0x00, 0x00 },  // 98
  { 0x00, 0x00, 0x00, 0x00, 0x3C, 0x20, 0x40, 0x40, 0x40, 0x60, 0x3C, 0x00, 0x00, 0x00, 0x00, 0x00 },  // 99
  { 0x00, 0x02, 0x02, 0x02, 0x1E, 0x22, 0x42, 0x42, 0x42, 0x66, 0x3A, 0x00, 0x00, 0x00, 0x00, 0x00 },  // 100
  { 0x00, 0x00, 0x00, 0x00, 0x3C, 0x66, 0x42, 0x7E, 0x40, 0x60, 0x3E, 0x00, 0x00, 0x00, 0x00, 0x00 },  // 101
  { 0x00, 0x0E, 0x10, 0x10, 0x10, 0x7C, 0x10, 0x10, 0x10, 0x10, 0x10, 0x00, 0x00, 0x00, 0x00, 0x00 },  // 102
  { 0x00, 0x00, 0x00, 0x00, 0x3E, 0x44, 0x44, 0x44, 0x78, 0x40, 0x7C, 0x42, 0x42, 0x3C, 0x00, 0x00 },  // 103
  { 0x00, 0x40, 0x40, 0x40, 0x58, 0x64, 0x44, 0x44, 0x44, 0x44, 0x44, 0x00, 0x00, 0x00, 0x00, 0x00 },  // 104
  { 0x00, 0x30, 0x30, 0x00, 0x70, 0x10, 0x10, 0x10, 0x10, 0x10, 0x7E, 0x00, 0x00, 0x00, 0x00, 0x00 },  // 105
  { 0x00, 0x0C, 0x0C, 0x00, 0x7C, 0x04, 0x04, 0x04, 0x04, 0x04, 0x04, 0x04, 0x0C, 0x78, 0x00, 0x00 },  // 106
  { 0x00, 0x40, 0x40, 0x40, 0x44, 0x48, 0x50, 0x60, 0x50, 0x48, 0x44, 0x00, 0x00, 0x00, 0x00, 0x00 },  // 107
  { 0x00, 0x70, 0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x7E, 0x00, 0x00, 0x00, 0x00, 0x00 },  // 108
  { 0x00, 0x00, 0x00, 0x00, 0xFE, 0xDA, 0x92, 0x92, 0x92, 0x92, 0x92, 0x00, 0x00, 0x00, 0x00, 0x00 },  // 109
  { 0x00, 0x00, 0x00, 0x00, 0x58, 0x64, 0x44, 0x44, 0x44, 0x44, 0x44, 0x00, 0x00, 0x00, 0x00, 0x00 },  // 110
  { 0x00, 0x00, 0x00, 0x00, 0x3C, 0x66, 0x42, 0x42, 0x42, 0x66, 0x3C, 0x00, 0x00, 0x00, 0x00, 0x00 },  // 111
  { 0x00, 0x00, 0x00, 0x00, 0x5C, 0x66, 0x42, 0x42, 0x42, 0x44, 0x78, 0x40, 0x40, 0x40, 0x00, 0x00 },  // 112
  { 0x00, 0x00, 0x00, 0x00, 0x1E, 0x22, 0x42, 0x42, 0x42, 0x66, 0x3A, 0x02, 0x02, 0x02, 0x00, 0x00 },  // 113
  { 0x00, 0x00, 0x00, 0x00, 0x58, 0x64, 0x44, 0x40, 0x40, 0x40, 0x40, 0x00, 0x00, 0x00, 0x00, 0x00 },  // 114
  { 0x00, 0x00, 0x00, 0x00, 0x3C, 0x40, 0x40, 0x38, 0x04, 0x04, 0x78, 0x00, 0x00, 0x00, 0x00, 0x00 },  // 115
  { 0x00, 0x00, 0x20, 0x20, 0xFC, 0x20, 0x20, 0x20, 0x20, 0x20, 0x1C, 0x00, 0x00, 0x00, 0x00, 0x00 },  // 116
  { 0x00, 0x00, 0x00, 0x00, 0x44, 0x44, 0x44, 0x44, 0x44, 0x4C, 0x34, 0x00, 0x00, 0x00, 0x00, 0x00 },  // 117
  { 0x00, 0x00, 0x00, 0x00, 0x22, 0x22, 0x32, 0x14, 0x14, 0x14, 0x08, 0x00, 0x00, 0x00, 0x00, 0x00 },  // 118
  { 0x00, 0x00, 0x00, 0x00, 0x82, 0x82, 0x92, 0xAA, 0xAA, 0xAA, 0x44, 0x00, 0x00, 0x00, 0x00, 0x00 },  // 119
  { 0x00, 0x00, 0x00, 0x00, 0x66, 0x24, 0x18, 0x18, 0x24, 0x66, 0xC3, 0x00, 0x00, 0x00, 0x00, 0x00 },  // 120
  { 0x00, 0x00, 0x00, 0x00, 0x22, 0x22, 0x36, 0x14, 0x14, 0x14, 0x08, 0x08, 0x10, 0x70, 0x00, 0x00 },  // 121
  { 0x00, 0x00, 0x00, 0x00, 0x7C, 0x08, 0x08, 0x10, 0x20, 0x20, 0x7C, 0x00, 0x00, 0x00, 0x00, 0x00 },  // 122
  { 0x00, 0x0C, 0x10, 0x10, 0x10, 0x10, 0x10, 0x60, 0x10, 0x10, 0x10, 0x10, 0x10, 0x0C, 0x00, 0x00 },  // 123
  { 0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x00, 0x00 },  // 124
  { 0x00, 0x30, 0x08, 0x08, 0x08, 0x08, 0x08, 0x06, 0x08, 0x08, 0x08, 0x08, 0x08, 0x30, 0x00, 0x00 },  // 125
  { 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xC4, 0x24, 0x18, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 },  // 126
};
// ============================ keys117: graphical menu ============================
STATIC EFI_GRAPHICS_OUTPUT_BLT_PIXEL   mGuiPixel;
STATIC EFI_GRAPHICS_OUTPUT_BLT_PIXEL   mGuiBuf[32 * 16];

STATIC
EFI_GRAPHICS_OUTPUT_BLT_PIXEL
Rgb (
  IN UINT32  Color
  )
{
  EFI_GRAPHICS_OUTPUT_BLT_PIXEL  P;
  P.Blue     = (UINT8)(Color & 0xFF);
  P.Green    = (UINT8)((Color >> 8) & 0xFF);
  P.Red      = (UINT8)((Color >> 16) & 0xFF);
  P.Reserved = 0;
  return P;
}

STATIC
VOID
GuiRect (
  IN UINTN   X,
  IN UINTN   Y,
  IN UINTN   W,
  IN UINTN   H,
  IN UINT32  Color
  )
{
  mGuiPixel = Rgb (Color);
  mGuiGop->Blt (mGuiGop, &mGuiPixel, EfiBltVideoFill, 0, 0, X, Y, W, H, 0);
}

STATIC
VOID
GuiGlyph (
  IN CHAR8   Ch,
  IN UINTN   X,
  IN UINTN   Y,
  IN UINTN   Scale,
  IN UINT32  Fg,
  IN UINT32  Bg
  )
{
  CONST UINT8  *Bits;
  UINTN         Row;
  UINTN         Col;
  UINTN         Dx;
  UINTN         Dy;
  UINTN         W;
  UINTN         H;

  if (Ch < 32 || Ch > 126) {
    Ch = '?';
  }
  Bits = mFont8x16[(UINT8)Ch - 32];
  W    = 8 * Scale;
  H    = 16 * Scale;
  for (Row = 0; Row < 16; Row++) {
    for (Col = 0; Col < 8; Col++) {
      BOOLEAN On = (BOOLEAN)((Bits[Row] >> (7 - Col)) & 1);
      EFI_GRAPHICS_OUTPUT_BLT_PIXEL Px = Rgb (On ? Fg : Bg);
      for (Dy = 0; Dy < Scale; Dy++) {
        for (Dx = 0; Dx < Scale; Dx++) {
          mGuiBuf[(Row * Scale + Dy) * W + (Col * Scale + Dx)] = Px;
        }
      }
    }
  }
  mGuiGop->Blt (mGuiGop, mGuiBuf, EfiBltBufferToVideo, 0, 0, X, Y, W, H, 0);
}

STATIC
VOID
GuiText (
  IN CONST CHAR8  *Text,
  IN UINTN         X,
  IN UINTN         Y,
  IN UINTN         Scale,
  IN UINT32        Fg,
  IN UINT32        Bg
  )
{
  UINTN  I;
  for (I = 0; Text[I] != 0; I++) {
    GuiGlyph (Text[I], X + I * 8 * Scale, Y, Scale, Fg, Bg);
  }
}

// keys120: full-screen status page (drawn, not printed)
STATIC
VOID
GuiStatusPage (
  IN CONST CHAR8  *Title,
  IN CONST CHAR8  *Line1,
  IN CONST CHAR8  *Line2,
  IN CONST CHAR8  *Line3
  )
{
  GuiRect (0, 0, 1440, 3200, 0x00101820);
  GuiRect (0, 0, 1440, 170, 0x00003060);
  GuiRect (0, 170, 1440, 8, 0x000080C0);
  GuiText (Title, 60, 45, 4, 0x00FFFFFF, 0x00003060);
  GuiText (Line1, 60, 420, 3, 0x00E0F0FF, 0x00101820);
  GuiText (Line2, 60, 560, 3, 0x00E0F0FF, 0x00101820);
  GuiText (Line3, 60, 700, 3, 0x00E0F0FF, 0x00101820);
  GuiText ("press VOL-UP or VOL-DOWN to go back", 60, 900, 2, 0x0080A0B0, 0x00101820);
}

STATIC
VOID
GuiMenu (
  VOID
  )
{
  static CONST CHAR8 *Items[5] = {
    "Boot Linux (UFS)",
    "Boot UniXNU",
    "Device information",
    "Reboot",
    "Power off"
  };
  UINTN       Selected = 0;
  UINTN       Index;
  UINTN       Y;
  EFI_STATUS  Status;
  EFI_INPUT_KEY Key;
  BOOLEAN     Redraw = TRUE;
  EFI_SIMPLE_TEXT_INPUT_PROTOCOL  *Ins[8];
  UINTN        InsCount = 0;
  UINTN        InsIdx;
  EFI_HANDLE  *Hbuf = NULL;
  UINTN        Hcnt = 0;
  CHAR8        KeyLine[64];          // keys119
  CHAR8        KeyLine2[64];         // keys124
  UINTN        LastScan = 0xFFFF;    // keys119
  UINTN        LastUni  = 0xFFFF;    // keys119
  UINTN        PendingAct = 0;       // keys119: selection awaiting confirm
  UINTN        ConfirmTicks = 0;     // keys119

  if (mGuiGop == NULL) {
    return;
  }

  // keys118: enumerate ALL SimpleTextIn instances (gST->ConIn does not deliver on this board)
  if (!EFI_ERROR (gBS->LocateHandleBuffer (ByProtocol, &gEfiSimpleTextInProtocolGuid, NULL, &Hcnt, &Hbuf))) {
    for (InsIdx = 0; InsIdx < Hcnt && InsCount < 8; InsIdx++) {
      VOID  *Ifc = NULL;
      if (!EFI_ERROR (gBS->HandleProtocol (Hbuf[InsIdx], &gEfiSimpleTextInProtocolGuid, &Ifc)) && Ifc != NULL) {
        Ins[InsCount++] = (EFI_SIMPLE_TEXT_INPUT_PROTOCOL *)Ifc;
      }
    }
    gBS->FreePool (Hbuf);
  }

  while (TRUE) {
    if (Redraw) {
      GuiRect (0, 0, 1440, 3200, 0x00101820);
      GuiRect (0, 0, 1440, 170, 0x00003060);
      GuiRect (0, 170, 1440, 8, 0x000080C0);
      GuiText ("VERMEER UEFI", 60, 40, 5, 0x00FFFFFF, 0x00003060);
      GuiText ("Project Silicium  /  Redmi K70", 60, 130, 2, 0x00A0C8E0, 0x00003060);

      Y = 420;
      for (Index = 0; Index < 5; Index++) {
        if (Index == Selected) {
          GuiRect (60, Y - 18, 1320, 110, 0x00004080);
          GuiRect (60, Y - 18, 14, 110, 0x0000C0FF);
          GuiText (Items[Index], 110, Y, 4, 0x00FFFFFF, 0x00004080);
        } else {
          GuiText (Items[Index], 110, Y, 4, 0x00C8D8E8, 0x00101820);
        }
        Y += 150;
      }

      GuiText ("VOL-UP / VOL-DOWN = move", 60, 1320, 2, 0x0080A0B0, 0x00101820);
      GuiText ("VOL-UP / VOL-DOWN = move   POWER/ENTER = select", 60, 1370, 2, 0x0080A0B0, 0x00101820);
      // keys119: live key status + confirm hint
      AsciiSPrint (KeyLine, sizeof (KeyLine), "last key: scan=0x%02x uni=0x%04x   %a",
                   LastScan, LastUni, (PendingAct != 0) ? "PRESS POWER AGAIN TO CONFIRM" : "");
      GuiText (KeyLine, 60, 1460, 2, 0x00FFD070, 0x00101820);
      // keys124: show how many block devices exist (our log disk shows up here)
      {
        UINTN       BlkCount = 0;
        EFI_HANDLE *BlkBuf   = NULL;

        if (EFI_ERROR (gBS->LocateHandleBuffer (ByProtocol, &gEfiBlockIoProtocolGuid,
                                                NULL, &BlkCount, &BlkBuf))) {
          BlkCount = 0;
        }
        if (BlkBuf != NULL) {
          gBS->FreePool (BlkBuf);
        }
        AsciiSPrint (KeyLine2, sizeof (KeyLine2), "BlockIO devices: %d", (UINT32)BlkCount);
        GuiText (KeyLine2, 60, 1510, 2, 0x00A0E0A0, 0x00101820);
      }

      if (Status == EFI_SUCCESS) { /* keep compiler quiet */ }
      Redraw = FALSE;
    }

    {
      Status = EFI_NOT_READY;
      for (InsIdx = 0; InsIdx < InsCount; InsIdx++) {
        if (!EFI_ERROR (Ins[InsIdx]->ReadKeyStroke (Ins[InsIdx], &Key))) {
          Status = EFI_SUCCESS;
          break;
        }
      }
      if (!EFI_ERROR (Status)) {
        LastScan = Key.ScanCode;   // keys119
        LastUni  = Key.UnicodeChar;
        if (Key.ScanCode == 0x01) {
          Selected = (Selected + 4) % 5;
          PendingAct = 0;
          Redraw   = TRUE;
        } else if (Key.ScanCode == 0x02) {
          Selected = (Selected + 1) % 5;
          PendingAct = 0;
          Redraw   = TRUE;
        } else {
          // keys121: safe items act immediately; dangerous ones need a 2nd press
          if (Selected != 3 && Selected != 4) {
            PendingAct = 0;
            Status     = EFI_SUCCESS;
            goto do_action;
          }
          if (PendingAct != Selected + 1) {
            PendingAct   = Selected + 1;
            ConfirmTicks = 0;
            Redraw       = TRUE;
          } else {
           do_action:
            if (Selected == 3) {
              gRT->ResetSystem (EfiResetCold, EFI_SUCCESS, 0, NULL);
            } else if (Selected == 4) {
              gRT->ResetSystem (EfiResetShutdown, EFI_SUCCESS, 0, NULL);
            } else if (Selected == 0) {
              GuiStatusPage ("BOOT LINUX (UFS)", "no block device yet", "UFS is not initialised", "so no ESP to boot from");
              PendingAct = 0;
              WaitAnyKey ();
              Redraw = TRUE;
            } else if (Selected == 1) {
              GuiStatusPage ("BOOT UNIXNU", "\\EFI\\UniXNU\\unixnu.efi", "not found - there is no", "file system yet");
              PendingAct = 0;
              WaitAnyKey ();
              Redraw = TRUE;
            } else {
              GuiStatusPage ("DEVICE INFORMATION", "Vermeer / Redmi K70", "GOP 1440x3200 ready", "volume keys + power OK");
              PendingAct = 0;
              WaitAnyKey ();
              Redraw = TRUE;
            }
          }
        }
      }
    }
    gBS->Stall (20000);
    if (PendingAct != 0) {           // keys119: confirm window ~3 s
      ConfirmTicks++;
      if (ConfirmTicks > 150) {
        PendingAct = 0;
        Redraw     = TRUE;
      }
    }
  }
}


//
// ============================ keys168: minimal EP0 ==========================
//
// DWC3 device-mode registers (same map used by keys158 / the reference impl).
//
#define USB168_BASE          0x0A600000
#define USB168_GSNPSID       0x0C120
#define USB168_GEVNTADRLO    0x0C400
#define USB168_GEVNTADRHI    0x0C404
#define USB168_GEVNTSIZ      0x0C408
#define USB168_GEVNTCOUNT    0x0C40C
#define USB168_GCTL          0x0C110
#define USB168_GSTS          0x0C118
#define USB168_GUSB2PHYCFG   0x0C200
#define USB168_DCFG          0x0C700
#define USB168_DCTL          0x0C704
#define USB168_DEVTEN        0x0C708
#define USB168_DSTS          0x0C70C
#define USB168_DALEPENA      0x0C720
#define USB168_DEPCMDPAR2(n) (0x0C800 + 0x10 * (n))
#define USB168_DEPCMDPAR1(n) (0x0C804 + 0x10 * (n))
#define USB168_DEPCMDPAR0(n) (0x0C808 + 0x10 * (n))
#define USB168_DEPCMD(n)     (0x0C80C + 0x10 * (n))

#define USB168_DCTL_RUN_STOP   (1U << 31)
#define USB168_DCTL_CSFTRST    (1U << 30)
#define USB168_DSTS_DEVCTRLHLT (1U << 22)
#define USB168_PHYCFG_CLEAR    ((1U << 31) | (1U << 8) | (1U << 6))

#define USB168_DEPCMD_SETEPCONFIG       1
#define USB168_DEPCMD_SETTRANSFRESOURCE 2
#define USB168_DEPCMD_SETSTALL          4
#define USB168_DEPCMD_STARTTRANSFER     6
#define USB168_DEPCMD_DEPSTARTCFG       9
#define USB168_DEPCMD_CMDACT            (1U << 10)

#define USB168_TRB_HWO      (1U << 0)
#define USB168_TRB_LST      (1U << 1)
#define USB168_TRB_ISP_IMI  (1U << 10)
#define USB168_TRB_IOC      (1U << 11)
#define USB168_TRBCTL_SETUP   (2U << 4)
#define USB168_TRBCTL_STATUS2 (3U << 4)
#define USB168_TRBCTL_STATUS3 (4U << 4)
#define USB168_TRBCTL_DATA    (5U << 4)

// DMA area layout inside one 16 KiB allocation.
#define USB168_EVT        0x0000
#define USB168_EVT_SIZE   0x1000
#define USB168_TRB_OUT    0x1000
#define USB168_TRB_IN     0x1010
#define USB168_SETUP      0x1040
#define USB168_DATA       0x1100
#define USB168_DMA_SIZE   0x4000

// Control-transfer states.
#define USB168_ST_SETUP        0
#define USB168_ST_DATA         1
#define USB168_ST_WAIT_STATUS2 2
#define USB168_ST_WAIT_STATUS3 3
#define USB168_ST_STATUS       4

#define USB168_MAX_STR 126

STATIC UINT8   *mUsb168Dma;
STATIC UINTN    mUsb168EvtPos;
STATIC UINT32   mUsb168State;
STATIC BOOLEAN  mUsb168DataIn;
STATIC UINT32   mUsb168Events;
STATIC BOOLEAN  mUsb168Ready;
STATIC UINT32   mUsb168SetupCount;
STATIC UINT32   mUsb168DescCount;
STATIC UINT32   mUsb168DepLogs;
STATIC UINT32   mUsb168RawLogs;
STATIC UINT32   mUsb168Bytes;
STATIC UINT32   mUsb168LastDsts;
STATIC UINT32   mUsb168LastCount;

STATIC UINT32
Usb168Rd (
  IN UINTN  Off
  )
{
  return *(volatile UINT32 *)(UINTN)(USB168_BASE + Off);
}

STATIC VOID
Usb168Wr (
  IN UINTN   Off,
  IN UINT32  Value
  )
{
  *(volatile UINT32 *)(UINTN)(USB168_BASE + Off) = Value;
  __asm__ __volatile__ ("dsb sy" ::: "memory");
}

STATIC VOID
Usb168Clean (
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
Usb168Inval (
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
Usb168Mark (
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
    mOut->OutputString (mOut, L"\r\n");
    mOut->OutputString (mOut, Buf);
  }
  gBS->Stall (20000);
}

STATIC VOID
Usb168Print (
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
Usb168EpCmd (
  IN UINT32  Ep,
  IN UINT32  Cmd,
  IN UINT32  Param0,
  IN UINT32  Param1,
  IN UINT32  Param2
  )
{
  UINTN   I;
  UINT32  Value;

  Usb168Wr (USB168_DEPCMDPAR2 (Ep), Param2);
  Usb168Wr (USB168_DEPCMDPAR1 (Ep), Param1);
  Usb168Wr (USB168_DEPCMDPAR0 (Ep), Param0);
  Usb168Wr (USB168_DEPCMD (Ep), Cmd | USB168_DEPCMD_CMDACT);

  for (I = 0; I < 200; I++) {
    Value = Usb168Rd (USB168_DEPCMD (Ep));
    if ((Value & USB168_DEPCMD_CMDACT) == 0) {
      if (mUsb168DepLogs++ < 80) {
        Usb168Print (L"  [168] dep n=%u cmd=%02x ok=%u st=%x",
                     Ep, Cmd & 0xF, (((Value >> 12) & 0xF) == 0) ? 1 : 0,
                     (Value >> 12) & 0xF);
      }
      if (((Value >> 12) & 0xF) != 0) {
        return EFI_DEVICE_ERROR;
      }
      return EFI_SUCCESS;
    }
    gBS->Stall (10);
  }
  if (mUsb168DepLogs++ < 80) {
    Usb168Print (L"  [168] dep n=%u cmd=%02x timeout", Ep, Cmd & 0xF);
  }
  return EFI_TIMEOUT;
}

STATIC VOID
Usb168Start (
  IN UINT32  Ep,
  IN UINTN   BufOff,
  IN UINT32  Length,
  IN UINT32  Ctl
  )
{
  volatile UINT32  *Trb;
  UINT64           BufPa;
  UINT64           TrbPa;

  Trb   = (volatile UINT32 *)(UINTN)(mUsb168Dma + (Ep ? USB168_TRB_IN : USB168_TRB_OUT));
  BufPa = (UINT64)(UINTN)(mUsb168Dma + BufOff);
  Trb[0] = (UINT32)BufPa;
  Trb[1] = (UINT32)(BufPa >> 32);
  Trb[2] = Length;
  Trb[3] = Ctl | USB168_TRB_HWO | USB168_TRB_LST | USB168_TRB_ISP_IMI | USB168_TRB_IOC;
  Usb168Clean ((UINTN)Trb, 16);
  if (Length != 0) {
    Usb168Clean ((UINTN)(mUsb168Dma + BufOff), Length);
  }
  TrbPa = (UINT64)(UINTN)Trb;
  Usb168EpCmd (Ep, USB168_DEPCMD_STARTTRANSFER, 0, (UINT32)TrbPa, (UINT32)(TrbPa >> 32));
}

STATIC VOID
Usb168ArmSetup (
  VOID
  )
{
  mUsb168State = USB168_ST_SETUP;
  Usb168Start (0, USB168_SETUP, 8, USB168_TRBCTL_SETUP);
}

STATIC VOID
Usb168Stall (
  VOID
  )
{
  Usb168EpCmd (0, USB168_DEPCMD_SETSTALL, 0, 0, 0);
  Usb168ArmSetup ();
}

STATIC CONST UINT8  mUsb168DevDesc[18] = {
  18, 1, 0x00, 0x02, 0x00, 0x00, 0x00, 64,
  0x09, 0x12, 0x01, 0x00, 0x00, 0x01, 1, 2, 3, 1
};

STATIC CONST UINT8  mUsb168CfgDesc[18] = {
  9, 2, 18, 0, 1, 1, 0, 0x80, 250,
  9, 4, 0, 0, 0, 0xFF, 0x00, 0x00, 0
};

STATIC CONST CHAR8  *mUsb168Strings[4] = {
  NULL, "Vermeer", "K70 UEFI DEBUG", "K70-0001"
};

STATIC UINT32
Usb168String (
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
  if (Index > 3) {
    return 0;
  }
  Str = mUsb168Strings[Index];
  N = 2;
  while ((*Str != 0) && (N < USB168_MAX_STR)) {
    Out[N++] = (UINT8)*Str++;
    Out[N++] = 0;
  }
  Out[0] = (UINT8)N;
  Out[1] = 3;
  return N;
}

STATIC VOID
Usb168Setup (
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

  St     = (CONST UINT8 *)(UINTN)(mUsb168Dma + USB168_SETUP);
  Data   = (UINT8 *)(UINTN)(mUsb168Dma + USB168_DATA);
  Type   = St[0];
  Req    = St[1];
  Value  = (UINT16)(St[2] | (St[3] << 8));
  Length = (UINT16)(St[6] | (St[7] << 8));
  N      = 0;
  Ok     = TRUE;

  mUsb168SetupCount++;
  if (mUsb168SetupCount <= 40) {
    Usb168Mark (L"[168] setup bm=%02x b=%02x wv=%04x wl=%04x",
                Type, Req, Value, Length);
  }
  mUsb168DataIn = ((Type & 0x80) != 0);

  if ((Type & 0x60) != 0) {
    Ok = FALSE;                       // only standard requests
  } else if (Req == 6) {             // GET_DESCRIPTOR
    switch ((UINT8)(Value >> 8)) {
    case 1:
      CopyMem (Data, mUsb168DevDesc, sizeof (mUsb168DevDesc));
      N = sizeof (mUsb168DevDesc);
      break;
    case 2:
      CopyMem (Data, mUsb168CfgDesc, sizeof (mUsb168CfgDesc));
      N = sizeof (mUsb168CfgDesc);
      break;
    case 3:
      N = Usb168String (Value & 0xFF, Data);
      Ok = (N != 0);
      break;
    default:
      Ok = FALSE;
      break;
    }
    if (Ok && (mUsb168DescCount++ < 40)) {
      Usb168Print (L"  [168] desc type=%02x len=%u", (UINT8)(Value >> 8), N);
    }
  } else if (Req == 5) {             // SET_ADDRESS
    Dcfg = Usb168Rd (USB168_DCFG) & ~(0x7FU << 3);
    Usb168Wr (USB168_DCFG, Dcfg | ((UINT32)(Value & 0x7F) << 3));
    Usb168Mark (L"[168] devaddr %u", Value & 0x7F);
  } else if (Req == 9) {             // SET_CONFIGURATION
    Usb168Print (L"  [168] configured cfg=%u", Value);
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
    Usb168Print (L"  [168] stall b=%02x", Req);
    Usb168Stall ();
    return;
  }
  if (Length == 0) {
    mUsb168State = USB168_ST_WAIT_STATUS2;
    return;
  }
  mUsb168State = USB168_ST_DATA;
  if (mUsb168DataIn) {
    if (N > Length) {
      N = Length;
    }
    Usb168Start (1, USB168_DATA, N, USB168_TRBCTL_DATA);
  } else {
    Usb168Start (0, USB168_DATA, 64, USB168_TRBCTL_DATA);
  }
}

STATIC VOID
Usb168Event (
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
    Usb168Print (L"  [168] dev evt type=%u", Type);
    if (Type == 1) {                 // USB reset
      Dcfg = Usb168Rd (USB168_DCFG) & ~(0x7FU << 3);
      Usb168Wr (USB168_DCFG, Dcfg);
      Usb168Print (L"  [168] bus reset");
    } else if (Type == 2) {          // connect done: EP0 max packet 64
      Speed = Usb168Rd (USB168_DSTS) & 7;
      Usb168EpCmd (0, USB168_DEPCMD_SETEPCONFIG, (0U << 1) | (64U << 3) | (2U << 30),
                   (1U << 8) | (1U << 10) | (0U << 25), 0);
      Usb168EpCmd (1, USB168_DEPCMD_SETEPCONFIG, (0U << 1) | (64U << 3) | (2U << 30),
                   (1U << 8) | (1U << 10) | (1U << 25), 0);
      Usb168Print (L"  [168] connect done speed=%u", Speed);
    } else if (Type == 0) {          // disconnect
      Usb168Print (L"  [168] disconnect");
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
    switch (mUsb168State) {
    case USB168_ST_SETUP:
      Usb168Inval ((UINTN)(mUsb168Dma + USB168_SETUP), 8);
      Usb168Setup ();
      break;
    case USB168_ST_DATA:
      mUsb168State = USB168_ST_WAIT_STATUS3;
      break;
    case USB168_ST_STATUS:
      Usb168ArmSetup ();
      break;
    default:
      break;
    }
    return;
  }

  if ((EvType == 3) && (Status == 2)) {  // XferNotReady, control status phase
    if ((mUsb168State == USB168_ST_WAIT_STATUS2) || (mUsb168State == USB168_ST_WAIT_STATUS3)) {
      UINT32 Ctl = (mUsb168State == USB168_ST_WAIT_STATUS3) ? USB168_TRBCTL_STATUS3 : USB168_TRBCTL_STATUS2;
      mUsb168State = USB168_ST_STATUS;
      Usb168Start (Ep, USB168_DATA, 0, Ctl);
    }
  }
}

STATIC VOID
Usb168Poll (
  VOID
  )
{
  UINT32  Count;
  UINT32  Done;
  UINT32  Ev;

  if (!mUsb168Ready) {
    return;
  }
  Count = Usb168Rd (USB168_GEVNTCOUNT) & 0xFFFF;
  if (Count == 0) {
    return;
  }
  Usb168Inval ((UINTN)(mUsb168Dma + USB168_EVT), USB168_EVT_SIZE);
  for (Done = 0; Done + 4 <= Count; Done += 4) {
    Ev = *(volatile UINT32 *)(UINTN)(mUsb168Dma + USB168_EVT + mUsb168EvtPos);
    mUsb168EvtPos = (mUsb168EvtPos + 4) % USB168_EVT_SIZE;
    mUsb168Events++;
    if (mUsb168RawLogs < 40) {
      mUsb168RawLogs++;
      Usb168Print (L"  [168] evt raw=%08x", Ev);
      if ((Ev & 1) == 0) {
        Usb168Print (L"  [168] dep evt raw=%08x", Ev);
      }
    }
    Usb168Event (Ev);
  }
  Usb168Wr (USB168_GEVNTCOUNT, Count);   // write back consumed bytes
  mUsb168Bytes += Count;
}

STATIC VOID
Usb168Stat (
  VOID
  )
{
  UINT32  Dsts;
  UINT32  Count;

  Dsts  = Usb168Rd (USB168_DSTS);
  Count = Usb168Rd (USB168_GEVNTCOUNT) & 0xFFFF;
  Usb168Print (L"  [168] poll: cnt=%08x DSTS=%08x DCTL=%08x", Count, Dsts,
               Usb168Rd (USB168_DCTL));
  if ((Dsts != mUsb168LastDsts) || (Count != mUsb168LastCount)) {
    mUsb168LastDsts  = Dsts;
    mUsb168LastCount = Count;
    Usb168Print (L"  [168] regs: GCTL=%08x PHYCFG=%08x DEVTEN=%08x SIZ=%08x",
                 Usb168Rd (USB168_GCTL), Usb168Rd (USB168_GUSB2PHYCFG),
                 Usb168Rd (USB168_DEVTEN), Usb168Rd (USB168_GEVNTSIZ));
  }
}

//
// keys168: Apps SMMU (SMMU-500) bypass for the DWC3 (USB0) stream.
// Base 0x15000000 is covered by the MemoryMapLib "SMMU" region, so no PEI change
// is needed.  xbl_ufs.dtb /soc/iort NAMEDNODE_USB0 SIDMAPPING: OutputBase = 0x40
// (OutputReference = APPS_MMU500_SMMU_APP).  SID 0x60 is only a fallback guess.
//
#define USB168_SMMU_BASE        0x15000000
#define USB168_SMMU_GR0_ID0     0x020
#define USB168_SMMU_GR0_ID1     0x024
#define USB168_SMMU_GR0_SMR(n)  (0x800 + ((n) * 4))
#define USB168_SMMU_GR0_S2CR(n) (0xC00 + ((n) * 4))
#define USB168_SMMU_SMR_VALID   0x80000000U
#define USB168_S2CR_TYPE_BYPASS (1U << 16)   // ARM SMMU-500 S2CR.TYPE: 0=trans, 1=bypass, 2=fault

STATIC UINT32
Usb168SmmuRd (
  IN UINTN Offset
  )
{
  return *(volatile UINT32 *)(UINTN)(USB168_SMMU_BASE + Offset);
}

STATIC VOID
Usb168SmmuWr (
  IN UINTN  Offset,
  IN UINT32 Value
  )
{
  *(volatile UINT32 *)(UINTN)(USB168_SMMU_BASE + Offset) = Value;
  gBS->Stall (10);
}

STATIC VOID
Usb168SmmuBypass (
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

  Id0     = Usb168SmmuRd (USB168_SMMU_GR0_ID0);
  Id1     = Usb168SmmuRd (USB168_SMMU_GR0_ID1);
  NumSmrg = Id0 & 0xFF;
  Usb168Print (L"  [168] smmu id0=%08x id1=%08x smrg=%u cb=%u", Id0, Id1, NumSmrg, Id1 & 0xFF);

  Shown = 0;
  Valid = 0;
  for (I = 0; I < NumSmrg; I++) {
    Smr = Usb168SmmuRd (USB168_SMMU_GR0_SMR (I));
    if ((Smr & USB168_SMMU_SMR_VALID) == 0) {
      continue;
    }
    Valid++;
    if (Shown < 10) {
      Usb168Print (L"  [168] smmu n=%u sid=%04x mask=%04x s2cr=%08x", I, Smr & 0xFFFF,
                   (Smr >> 16) & 0xFFFF, Usb168SmmuRd (USB168_SMMU_GR0_S2CR (I)));
      Shown++;
    }
  }
  Usb168Print (L"  [168] smmu valid=%u of %u", Valid, NumSmrg);

  for (J = 0; J < ARRAY_SIZE (Cands); J++) {
    Want = Cands[J];
    S2cr = 0;
    for (I = 0; I < NumSmrg; I++) {
      Smr = Usb168SmmuRd (USB168_SMMU_GR0_SMR (I));
      if (((Smr & USB168_SMMU_SMR_VALID) != 0) && ((Smr & 0xFFFF) == Want)) {
        S2cr = Usb168SmmuRd (USB168_SMMU_GR0_S2CR (I));
        break;
      }
    }
    if (I < NumSmrg) {
      New = USB168_S2CR_TYPE_BYPASS | (S2cr & 0xFF);
      Usb168SmmuWr (USB168_SMMU_GR0_S2CR (I), New);
      Usb168Print (L"  [168] smmu bypass sid=%04x n=%u s2cr %08x -> %08x", Want, I, S2cr,
                   Usb168SmmuRd (USB168_SMMU_GR0_S2CR (I)));
      continue;
    }
    for (I = 0; I < NumSmrg; I++) {
      if ((Usb168SmmuRd (USB168_SMMU_GR0_SMR (I)) & USB168_SMMU_SMR_VALID) == 0) {
        break;
      }
    }
    if (I < NumSmrg) {
      Usb168SmmuWr (USB168_SMMU_GR0_S2CR (I), USB168_S2CR_TYPE_BYPASS);
      Usb168SmmuWr (USB168_SMMU_GR0_SMR (I), USB168_SMMU_SMR_VALID | (Want & 0xFFFF));
      Usb168Print (L"  [168] smmu created sid=%04x n=%u smr=%08x s2cr=%08x", Want, I,
                   Usb168SmmuRd (USB168_SMMU_GR0_SMR (I)),
                   Usb168SmmuRd (USB168_SMMU_GR0_S2CR (I)));
    } else {
      Usb168Print (L"  [168] smmu no free slot for sid=%04x", Want);
    }
  }
}

STATIC VOID
Usb168Init (
  VOID
  )
{
  EFI_PHYSICAL_ADDRESS  DmaPa;
  EFI_STATUS            Status;
  UINTN                 I;
  UINTN                 Ticks;
  UINT32                Gsnpsid;
  UINT32                Dsts;

  //
  // keys168: force the event ring / TRB DMA below 4 GiB (32-bit DMA safe).
  //
  DmaPa  = 0xFFFFF000ULL;
  Status = gBS->AllocatePages (AllocateMaxAddress, EfiBootServicesData, USB168_DMA_SIZE / 0x1000, &DmaPa);
  if (EFI_ERROR (Status)) {
    Say (L"  [168] FATAL: no DMA pages");
    return;
  }
  mUsb168Dma = (UINT8 *)(UINTN)DmaPa;
  ZeroMem (mUsb168Dma, USB168_DMA_SIZE);
  Usb168Print (L"  [168] dma=%08x%08x (16 KiB)", (UINT32)(((UINT64)(UINTN)mUsb168Dma) >> 32),
               (UINT32)(UINTN)mUsb168Dma);
  Usb168Mark (L"[168] dma done");

  //
  // 1) NO device soft reset in keys168: DCTL.CSFTRST soft-resets the PHY/clocks domain
  //    on this SoC and has been observed to kill the upstream connection entirely.
  //    Only clear PHY suspend / suspend-on-sleep / PHY soft-reset and let it settle.
  //
  Usb168Wr (USB168_GUSB2PHYCFG, Usb168Rd (USB168_GUSB2PHYCFG) & ~USB168_PHYCFG_CLEAR);
  gBS->Stall (20000);

  //
  // 1b) Guarantee DCTL.CSFTRST stays 0 WITHOUT pulsing it (a read-modify-write that
  //     only clears bit30 never triggers the reset).
  //
  if ((Usb168Rd (USB168_DCTL) & USB168_DCTL_CSFTRST) != 0) {
    Usb168Wr (USB168_DCTL, Usb168Rd (USB168_DCTL) & ~USB168_DCTL_CSFTRST);
    gBS->Stall (1000);
  }
  Usb168Print (L"  [168] phycfg=%08x gctl=%08x dctl=%08x", Usb168Rd (USB168_GUSB2PHYCFG),
               Usb168Rd (USB168_GCTL), Usb168Rd (USB168_DCTL));
  Usb168Mark (L"[168] phy ready");

  //
  // 1c) keys168: bypass the Apps SMMU for the DWC3 stream(s) before touching the
  //     event ring, so event-DMA writes can no longer be silently dropped.
  //
  Usb168SmmuBypass ();
  Usb168Mark (L"[168] smmu bypass done");

  //
  // 2) Event buffer, interrupt masked (bit31), polled from the resident loop.
  //
  //
  // keys168: vendor write order (ADDRHI -> ADDRLO -> SIZ -> COUNT) and the vendor
  // value for GEVNTSIZ: bit31 = interrupt masked (0x80000000 | size), polled only.
  //
  Usb168Wr (USB168_GEVNTADRHI, (UINT32)(((UINT64)(UINTN)mUsb168Dma) >> 32));
  Usb168Wr (USB168_GEVNTADRLO, (UINT32)(UINTN)mUsb168Dma);
  Usb168Wr (USB168_GEVNTSIZ,   ((UINT32)1 << 31) | USB168_EVT_SIZE);
  Usb168Wr (USB168_GEVNTCOUNT, 0);
  mUsb168EvtPos = 0;
  Usb168Print (L"  [168] evt: addr=%08x%08x siz=%08x cnt=%08x",
               Usb168Rd (USB168_GEVNTADRHI), Usb168Rd (USB168_GEVNTADRLO),
               Usb168Rd (USB168_GEVNTSIZ), Usb168Rd (USB168_GEVNTCOUNT));
  Usb168Mark (L"[168] evt ring set");

  //
  // 3) High speed, address 0; device events: disconnect / USB reset / connect done.
  //
  Usb168Wr (USB168_DCFG, Usb168Rd (USB168_DCFG) & ~(7U | (0x7FU << 3)));
  Usb168Wr (USB168_DEVTEN, 0x1277);   // vendor value: device events incl. connect/reset

  //
  // 4) EP0 OUT (dep 0) and EP0 IN (dep 1), control type, mps 512 for now.
  //
  Usb168EpCmd (0, USB168_DEPCMD_DEPSTARTCFG, 0, 0, 0);
  Usb168EpCmd (0, USB168_DEPCMD_SETEPCONFIG, (0U << 1) | (512U << 3),
               (1U << 8) | (1U << 10) | (0U << 25), 0);
  Usb168EpCmd (0, USB168_DEPCMD_SETTRANSFRESOURCE, 1, 0, 0);
  Usb168EpCmd (1, USB168_DEPCMD_SETEPCONFIG, (0U << 1) | (512U << 3),
               (1U << 8) | (1U << 10) | (1U << 25), 0);
  Usb168EpCmd (1, USB168_DEPCMD_SETTRANSFRESOURCE, 1, 0, 0);
  Usb168Wr (USB168_DALEPENA, 0x3);
  Usb168Mark (L"[168] ep armed");

  //
  // 5) Run: if the core is halted, toggle RUN_STOP off/on (up to 3 attempts, never
  //    touching CSFTRST), then arm the SETUP TRB once DSTS reports not-halted.
  //
  for (I = 0; I < 3; I++) {
    if ((Usb168Rd (USB168_DSTS) & USB168_DSTS_DEVCTRLHLT) == 0) {
      break;
    }
    Usb168Wr (USB168_DCTL, Usb168Rd (USB168_DCTL) & ~USB168_DCTL_RUN_STOP);
    gBS->Stall (1000);
    Usb168Wr (USB168_DCTL, Usb168Rd (USB168_DCTL) | USB168_DCTL_RUN_STOP);
    for (Ticks = 0; Ticks < 200; Ticks++) {
      if ((Usb168Rd (USB168_DSTS) & USB168_DSTS_DEVCTRLHLT) == 0) {
        break;
      }
      gBS->Stall (1000);
    }
  }
  //
  // 5b) keys168: force a *fresh* host enumeration.  Clearing DCTL.RUN_STOP stops
  //     the device controller from driving the D+ pull-up, i.e. the host sees an
  //     electrical disconnect; setting it again is a reconnect.  This is the
  //     software equivalent of Linux dwc3_gadget_pullup(0 -> 1) and makes the
  //     host restart enumeration (connect done + USB reset + SETUP), which is
  //     what never happens if the host already gave up before our EP0 was armed.
  //
  Usb168Print (L"  [168] replug: pull-up off (DCTL.RUN_STOP=0)");
  Usb168Wr (USB168_DCTL, Usb168Rd (USB168_DCTL) & ~USB168_DCTL_RUN_STOP);
  gBS->Stall (150000);
  Usb168Print (L"  [168] replug: pull-up on (DCTL.RUN_STOP=1)");
  Usb168Wr (USB168_DCTL, Usb168Rd (USB168_DCTL) | USB168_DCTL_RUN_STOP);
  gBS->Stall (150000);
  for (I = 0; I < 200; I++) {
    if ((Usb168Rd (USB168_DSTS) & USB168_DSTS_DEVCTRLHLT) == 0) {
      break;
    }
    gBS->Stall (1000);
  }
  //
  // 5c) The stop/start may have dropped the endpoint resources: re-issue the
  //     EP0 configuration if DALEPENA no longer shows both endpoints enabled.
  //
  if ((Usb168Rd (USB168_DALEPENA) & 0x3) != 0x3) {
    Usb168Print (L"  [168] ep cfg redo after replug");
    Usb168EpCmd (0, USB168_DEPCMD_DEPSTARTCFG, 0, 0, 0);
    Usb168EpCmd (0, USB168_DEPCMD_SETEPCONFIG, (0U << 1) | (512U << 3),
                 (1U << 8) | (1U << 10) | (0U << 25), 0);
    Usb168EpCmd (0, USB168_DEPCMD_SETTRANSFRESOURCE, 1, 0, 0);
    Usb168EpCmd (1, USB168_DEPCMD_SETEPCONFIG, (0U << 1) | (512U << 3),
                 (1U << 8) | (1U << 10) | (1U << 25), 0);
    Usb168EpCmd (1, USB168_DEPCMD_SETTRANSFRESOURCE, 1, 0, 0);
    Usb168Wr (USB168_DALEPENA, 0x3);
  }
  Usb168Print (L"  [168] replug done: hlt22=%d DSTS=%08x DALEPENA=%08x",
               (Usb168Rd (USB168_DSTS) >> 22) & 1, Usb168Rd (USB168_DSTS),
               Usb168Rd (USB168_DALEPENA));
  Usb168Mark (L"[168] replug done");
  mUsb168State = USB168_ST_SETUP;
  Usb168ArmSetup ();
  Usb168Print (L"  [168] ep0 armed (setup TRB queued, waiting for host SETUP)");
  Usb168Mark (L"[168] ep0 armed");
  Dsts    = Usb168Rd (USB168_DSTS);
  Gsnpsid = Usb168Rd (USB168_GSNPSID);
  mUsb168Ready = TRUE;
  Usb168Print (L"  [168] gadget up: GSNPSID=%08x GCTL=%08x DCFG=%08x DEVTEN=%08x",
               Gsnpsid, Usb168Rd (USB168_GCTL), Usb168Rd (USB168_DCFG),
               Usb168Rd (USB168_DEVTEN));
  Usb168Print (L"  [168] up2: DALEPENA=%08x DSTS=%08x hlt22=%d spd=%u",
               Usb168Rd (USB168_DALEPENA), Dsts, (Dsts >> 22) & 1, Dsts & 7);
  Usb168Print (L"  [168] bringup done: hlt22=%d phycfg_bit6=%d devspd=%u evtaddr=%08x%08x",
               (Dsts >> 22) & 1, (Usb168Rd (USB168_GUSB2PHYCFG) >> 6) & 1, Dsts & 7,
               Usb168Rd (USB168_GEVNTADRHI), Usb168Rd (USB168_GEVNTADRLO));
  Usb168Mark (L"[168] init done");
}

EFI_STATUS
EFIAPI
VermeerMenuDxeEntry (
  IN EFI_HANDLE        ImageHandle,
  IN EFI_SYSTEM_TABLE  *SystemTable
  )
{
  EFI_STATUS  Status;
  CHAR16      Line[128];

  mOut = gST->ConOut;
  mIn  = gST->ConIn;

  if (mOut == NULL) {
    gBS->LocateProtocol (&gEfiSimpleTextOutProtocolGuid, NULL, (VOID **)&mOut);
  }

  if (mOut != NULL) {
    UnicodeSPrint (Line, sizeof (Line), L"  [MENU102] entry: ConOut=%d ConIn=%d",
                   (mOut == NULL) ? 0 : 1, (mIn == NULL) ? 0 : 1);
    Say (Line);
  }

  if (mIn == NULL) {
    Status = gBS->LocateProtocol (&gEfiSimpleTextInProtocolGuid, NULL, (VOID **)&mIn);
    if (mOut != NULL) {
      UnicodeSPrint (Line, sizeof (Line), L"  [MENU102] LocateProtocol(SimpleTextIn) -> %r", Status);
      Say (Line);
    }
  }

  if (mIn == NULL) {
    if (mOut != NULL) {
      Say (L"  [MENU102] no console input at all - returning, BDS may reset");
    }

    return EFI_SUCCESS;
  }

  Say (L"[MENU168] keys168 console landmarks, no clear, resident EP0 loop");
  Usb168Mark (L"[168] menu entered");
  {
    STATIC UINTN  mGuiDisabled168 = 0;
    STATIC UINTN  mTicks168       = 0;
    STATIC UINTN  mLastReplug168  = 0;

    Usb168Mark (L"[168] init start");
    Usb168Init ();
    Usb168Mark (L"[168] loop start");
    for (;;) {
      Usb168Poll ();
      if ((mTicks168 % 2000) == 0) {
        Usb168Stat ();
        Usb168Mark (L"[168] alive evts=%u", mUsb168Events);
      }
      if ((mTicks168 - mLastReplug168) >= 5000) {
        mLastReplug168 = mTicks168;
        Usb168Mark (L"[168] replug retry");
        Usb168Wr (USB168_DCTL, Usb168Rd (USB168_DCTL) & ~USB168_DCTL_RUN_STOP);
        gBS->Stall (150000);
        Usb168Wr (USB168_DCTL, Usb168Rd (USB168_DCTL) | USB168_DCTL_RUN_STOP);
        gBS->Stall (150000);
        mUsb168State = USB168_ST_SETUP;
        Usb168ArmSetup ();
      }
      if (mGuiDisabled168 == 0xFFFFFFFFU) {
        RunMenu ();
      }
      mTicks168++;
      gBS->Stall (1000);
    }
  }


  return EFI_SUCCESS;
}