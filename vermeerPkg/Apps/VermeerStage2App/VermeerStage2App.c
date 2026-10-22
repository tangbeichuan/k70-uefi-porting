#include <Uefi.h>
#include <Library/UefiBootServicesTableLib.h>
#include <Library/DebugLib.h>
#include <Library/BaseLib.h>

STATIC CONST CHAR8 mPage[] =
  "\n"
  "\n"
  "   ============================================\n"
  "        U n i X N U   (embedded stage-2 page)\n"
  "   ============================================\n"
  "\n"
  "   version 0.1.0-lab    config: \\EFI\\UniXNU\\unixnu.toml\n"
  "\n"
  "     1  Hello payload (full injection)     efi\n"
  "     2  Hello payload (plain)              efi\n"
  "     3  Restart                            action\n"
  "     4  Power off                          action\n"
  "\n"
  "   Up/Down: select   Enter: boot   Esc: stop timer\n"
  "\n"
  "   drivers 0 loaded / 0 failed    kits 0    acpi 0\n"
  "\n"
  "   [STAGE2] this page is an EFI application embedded in the firmware FV,\n"
  "   [STAGE2] launched by VermeerKeyProbeDxe via LoadImage()/StartImage().\n"
  "   [STAGE2] it proves the firmware->EFI-application handoff works.\n"
  "   [STAGE2] real UniXNU needs: UniXNU.efi + a filesystem (ESP) to read\n"
  "   [STAGE2] \\EFI\\UniXNU\\unixnu.toml and its kits from.\n"
  "\n"
  "   === STAGE2 HALT ===\n";

EFI_STATUS
EFIAPI
VermeerStage2AppEntry (
  IN EFI_HANDLE        ImageHandle,
  IN EFI_SYSTEM_TABLE  *SystemTable
  )
{
  if ((gST != NULL) && (gST->ConOut != NULL)) {
    gST->ConOut->OutputString (gST->ConOut, (CHAR16 *)L"\r\n[STAGE2] hello from embedded app\r\n");
  }
  DEBUG ((DEBUG_ERROR, "%a", mPage));
  CpuDeadLoop ();
  return EFI_SUCCESS;
}