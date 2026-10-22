/** @file
  Map the UFS controller IO window so that the vendor UFSDxe can reach it.

  The PEI-phase MemoryMapLib table must not be touched (doing so hangs PEI),
  so we add the region at runtime, before UFSDxe is dispatched.
**/
#include <Uefi.h>
#include <Library/UefiBootServicesTableLib.h>
#include <Library/DxeServicesTableLib.h>
#include <Library/DebugLib.h>

#define UFS_MMIO_BASE   0x01D80000ULL
#define UFS_MMIO_SIZE   0x00020000ULL

EFI_STATUS
EFIAPI
VermeerUfsMapDxeEntry (
  IN EFI_HANDLE        ImageHandle,
  IN EFI_SYSTEM_TABLE  *SystemTable
  )
{
  EFI_STATUS  Status;

  if (gDS == NULL) {
    DEBUG ((DEBUG_ERROR, "[UFSMAP] gDS is NULL\n"));
    return EFI_SUCCESS;
  }

  Status = gDS->AddMemorySpace (
                  EfiGcdMemoryTypeMemoryMappedIo,
                  UFS_MMIO_BASE,
                  UFS_MMIO_SIZE,
                  EFI_MEMORY_UC | EFI_MEMORY_RUNTIME
                  );
  DEBUG ((DEBUG_ERROR, "[UFSMAP] AddMemorySpace 0x%lx+0x%lx -> %r\n",
          UFS_MMIO_BASE, UFS_MMIO_SIZE, Status));

  if (!EFI_ERROR (Status)) {
    Status = gDS->SetMemorySpaceAttributes (UFS_MMIO_BASE, UFS_MMIO_SIZE, EFI_MEMORY_UC);
    DEBUG ((DEBUG_ERROR, "[UFSMAP] SetMemorySpaceAttributes -> %r\n", Status));
  }

  return EFI_SUCCESS;
}
