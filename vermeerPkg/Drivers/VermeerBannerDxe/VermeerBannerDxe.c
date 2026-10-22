/** @file
  Persistent on-screen banner + heartbeat for the Redmi K70 (vermeer) UEFI port.

  Why this exists
  ---------------
  The port's only output channel on the phone is the panel, and the DEBUG log written by
  SiliciumPkg's FrameBufferSerialPortLib scrolls off the top of a 3200 px screen after
  roughly 50 lines.  A black screen then says nothing, and a screen full of scrolled log
  says only "something ran".

  This driver prints a fixed banner and then keeps rewriting a heartbeat counter, using
  BOTH channels on purpose:

    * DEBUG / DebugPrint -> the platform's SerialPortLib.  On the phone that is
      FrameBufferSerialPortLib, i.e. text drawn straight into "Display Reserved"; on the
      QEMU diagnostic build it is the PL011, i.e. a text log.  This channel is guaranteed
      to exist because it is a library, so the banner appears even if the console stack is
      not wired up yet.
    * gST->ConOut -> the console stack (ConSplitter -> GraphicsConsoleDxe -> GOP).  This is
      the weaker claim ("the console stack works"), and it is printed second because a
      console that is not connected yet must not be able to stop the banner.

  A ticking counter is the cheapest proof that the UEFI event loop and the panel path are
  both alive, and it does not depend on reading a scrolling log.

  It never returns, so a diagnostic image that includes it stops here with something useful
  on screen instead of trying to boot, failing, and resetting the machine.

  Gated behind VERMEER_BANNER in vermeer.dsc / vermeer.fdf, default 0: the shipping images
  do not contain it.
**/

#include <Uefi.h>
#include <Library/UefiBootServicesTableLib.h>
#include <Library/UefiLib.h>
#include <Library/DebugLib.h>
#include <Library/BaseLib.h>
#include <Library/PrintLib.h>

#define HEARTBEAT_US  (500 * 1000)

//
// Kept to <= 60 columns and ASCII only: the platform console is 1440 px wide at font scale
// 3, which is about 60 characters, and a fixed-width ASCII banner cannot be corrupted by a
// font or encoding mismatch.
//
STATIC CONST CHAR8  mBannerA[] =
  "\n"
  "==========================================================\n"
  " Redmi K70 (vermeer, SM8550) - Mu-Silicium UEFI port\n"
  " If you can read this, the ported firmware is running.\n"
  "==========================================================\n"
  "\n"
  " What this proves: SEC -> PEI -> DXE -> BDS all ran, the\n"
  " frame buffer was found by its \"Display Reserved\" name,\n"
  " and this driver is executing in the UEFI event loop.\n"
  "\n"
  " The counter should keep increasing. If it stops, the\n"
  " firmware hung; if the screen stays black, the panel path\n"
  " is the problem - the CPU and memory map are not.\n"
  "\n";

STATIC CONST CHAR16  mBannerW[] =
  L"\r\n"
  L"==========================================================\r\n"
  L" Redmi K70 (vermeer, SM8550) - Mu-Silicium UEFI port\r\n"
  L" If you can read this, the ported firmware is running.\r\n"
  L"==========================================================\r\n"
  L"\r\n";

/**
  Entry point: print the banner on both channels, then a heartbeat counter, forever.

  @param[in] ImageHandle  Image handle of this driver.
  @param[in] SystemTable  Pointer to the EFI System Table.

  @retval EFI_SUCCESS     Never actually returns.
**/
EFI_STATUS
EFIAPI
VermeerBannerDxeEntry (
  IN EFI_HANDLE        ImageHandle,
  IN EFI_SYSTEM_TABLE  *SystemTable
  )
{
  UINTN   Tick;
  CHAR8   LineA[64];
  CHAR16  LineW[64];
  BOOLEAN HaveConOut;

  //
  // 1. Guaranteed channel first: a library, not a protocol.
  //
  DEBUG ((DEBUG_ERROR, "%a", mBannerA));

  //
  // 2. Console stack second, and only if it is there.
  //
  HaveConOut = ((gST != NULL) && (gST->ConOut != NULL));
  if (HaveConOut) {
    if (EFI_ERROR (gST->ConOut->OutputString (gST->ConOut, (CHAR16 *)mBannerW))) {
      HaveConOut = FALSE;
    }
  }

  DEBUG ((DEBUG_ERROR, "VermeerBannerDxe: banner printed (ConOut %a)\n",
          HaveConOut ? "ok" : "unavailable"));

  //
  // 3. Heartbeat: carriage return, no newline, so the counter overwrites itself on one
  //    line and the banner above it stays readable on the panel.
  //
  for (Tick = 1; ; Tick++) {
    AsciiSPrint (LineA, sizeof (LineA), "\r  heartbeat %d   ", (UINTN)Tick);
    DEBUG ((DEBUG_ERROR, "%a", LineA));

    if (HaveConOut) {
      UnicodeSPrint (LineW, sizeof (LineW), L"\r  heartbeat %d   ", (UINTN)Tick);
      gST->ConOut->OutputString (gST->ConOut, LineW);
    }

    gBS->Stall (HEARTBEAT_US);
  }

  return EFI_SUCCESS;
}
