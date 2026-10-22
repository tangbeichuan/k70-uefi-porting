/** @file
  Paints the live "Display Reserved" frame buffer as early telemetry.

  This board exposes no UART, so the screen is the only output channel. Three
  very different failures look identical on it (black, no output):

    1. the bootloader refused the boot.img          -> seen by the BootShim marker
    2. the firmware does not reach DXE dispatch     -> nothing else can report it
    3. DXE runs but the frame buffer geometry is off -> text is written but lands
                                                       outside the visible scanout

  This driver covers 2 and 3 without trusting any geometry: it fills the whole
  "Display Reserved" window (43 MiB, far larger than the 18.4 MiB 1440x3200
  surface) with a solid colour, then animates a top band once per timer tick.
  Because the fill covers the entire reserved window, it does not matter which
  stride or resolution the panel is actually scanning out at hand-off.

  Reading the result:

    * no change at all from the stock splash -> DXE never ran this driver
    * whole screen turns dark blue, then a band cycles colours every 500 ms
      -> DXE is alive, the frame buffer base is right, and timers fire
    * screen stays dark blue with a frozen band -> DXE ran but the event loop
      stopped (something else hangs after this driver)

  It keeps animating instead of drawing once, because a moving band proves the
  event loop is still running some seconds after DXE dispatch started.

  Only built when VERMEER_PAINT=1, so the shipping firmware is unaffected.
**/

#include <Uefi.h>

#include <Library/BaseLib.h>
#include <Library/DebugLib.h>
#include <Library/MemoryMapHelperLib.h>
#include <Library/UefiBootServicesTableLib.h>
#include <Library/UefiLib.h>

//
// Colours are 32-bit little-endian pixels in the panel's native
// PixelBlueGreenRedReserved8BitPerColor order, i.e. 0x00RRGGBB.
//
#define PAINT_BACKGROUND  0x00601008u
#define PAINT_BAND_HEIGHT (4u * 1024u * 1024u)  // 4 MiB of the top of the window
#define PAINT_TICK_US     500000u

STATIC volatile UINT32  *mFrameBuffer;
STATIC UINT64            mFrameBufferBytes;
STATIC volatile UINT32   mTick;
STATIC EFI_EVENT         mTimerEvent;

STATIC CONST UINT32  mPalette[] = {
  0x000000FFu,  // red
  0x0000FF00u,  // green
  0x00FF0000u,  // blue
  0x0000FFFFu,  // yellow
  0x00FF00FFu,  // magenta
  0x00FFFF00u,  // cyan
  0x00FFFFFFu,  // white
  0x00804020u,  // brown
};

STATIC
VOID
FillRange (
  IN UINT64  OffsetBytes,
  IN UINT64  LengthBytes,
  IN UINT32  Colour
  )
{
  volatile UINT32  *Cursor;
  UINT64            Pixels;

  if (OffsetBytes >= mFrameBufferBytes) {
    return;
  }

  if (LengthBytes > mFrameBufferBytes - OffsetBytes) {
    LengthBytes = mFrameBufferBytes - OffsetBytes;
  }

  Cursor = mFrameBuffer + (OffsetBytes / sizeof (UINT32));
  Pixels = LengthBytes / sizeof (UINT32);
  while (Pixels-- != 0) {
    *Cursor++ = Colour;
  }
}

STATIC
VOID
EFIAPI
PaintTick (
  IN EFI_EVENT  Event,
  IN VOID      *Context
  )
{
  UINT32  Colour;

  Colour = mPalette[mTick % ARRAY_SIZE (mPalette)];
  mTick++;

  //
  // A band at the top of the window, one sixth of it per tick so that a single
  // pass fills the band with the same colour: it is easier to judge on a photo.
  //
  FillRange ((UINT64)(mTick % 6) * (PAINT_BAND_HEIGHT / 6), PAINT_BAND_HEIGHT / 6, Colour);

  if ((mTick % 12) == 0) {
    DEBUG ((DEBUG_ERROR, "VermeerPaintDxe: tick %u, colour 0x%08x\n", mTick, Colour));
  }
}

EFI_STATUS
EFIAPI
VermeerPaintDxeEntry (
  IN EFI_HANDLE        ImageHandle,
  IN EFI_SYSTEM_TABLE  *SystemTable
  )
{
  EFI_STATUS                    Status;
  EFI_MEMORY_REGION_DESCRIPTOR  Region;
  EFI_EVENT                     TimerEvent;

  Status = LocateMemoryRegionByName ("Display Reserved", &Region);
  if (EFI_ERROR (Status)) {
    DEBUG ((DEBUG_ERROR, "VermeerPaintDxe: no \"Display Reserved\" region: %r\n", Status));
    return EFI_SUCCESS;  // never block the boot for telemetry
  }

  mFrameBuffer      = (volatile UINT32 *)(UINTN)Region.Address;
  mFrameBufferBytes = Region.Length;

  DEBUG ((
    DEBUG_ERROR,
    "VermeerPaintDxe: painting 0x%lx bytes at 0x%lx\n",
    (UINT64)Region.Length,
    (UINT64)Region.Address
    ));

  //
  // Step 1: solid background over the whole window. Geometry-independent.
  //
  FillRange (0, mFrameBufferBytes, PAINT_BACKGROUND);

  //
  // Step 2: a bright magenta band at the top, so even a partially visible
  // screen shows something.
  //
  FillRange (0, PAINT_BAND_HEIGHT, 0x00FF00FFu);

  //
  // Step 3: keep animating. A live animation proves the DXE event loop runs.
  //
  TimerEvent = NULL;
  Status     = gBS->CreateEvent (
                      EVT_TIMER | EVT_NOTIFY_SIGNAL,
                      TPL_CALLBACK,
                      PaintTick,
                      NULL,
                      &TimerEvent
                      );
  if (EFI_ERROR (Status)) {
    DEBUG ((DEBUG_ERROR, "VermeerPaintDxe: CreateEvent failed: %r\n", Status));
    return EFI_SUCCESS;
  }

  Status = gBS->SetTimer (TimerEvent, TimerPeriodic, PAINT_TICK_US);
  if (EFI_ERROR (Status)) {
    DEBUG ((DEBUG_ERROR, "VermeerPaintDxe: SetTimer failed: %r\n", Status));
    gBS->CloseEvent (TimerEvent);
    return EFI_SUCCESS;
  }

  mTimerEvent = TimerEvent;
  DEBUG ((DEBUG_ERROR, "VermeerPaintDxe: animating, tick interval %u us\n", PAINT_TICK_US));

  return EFI_SUCCESS;
}
