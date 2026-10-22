/** @file
  VermeerPmicVerStubDxe - installs a benign "PMIC version" protocol so that
  vendor UsbConfigDxe can proceed without a real PMIC driver.

  Reverse engineered from UsbConfigDxe.efi:
    adrp x0,0x13000 / add x0,x0,#0x178  -> GUID 4684800A-2755-4EDC-B443-7F8CEB3239D3
    ldr x8,[ifc] / ldr x8,[x8,#8] / w0=7 / x1=&out(u32)
  Returning 0x7FFFFFFF means "version not available"; the driver then takes its
  fallback path instead of dereferencing garbage.

  Copyright (c) 2026, K70 UEFI port. SPDX-License-Identifier: BSD-2-Clause-Patent
**/

#include <Uefi.h>
#include <Library/UefiBootServicesTableLib.h>
#include <Library/DebugLib.h>
#include <Protocol/GraphicsOutput.h>

STATIC CONST EFI_GUID  mPmicVerGuid = {
  0x4684800A, 0x2755, 0x4EDC, { 0xB4, 0x43, 0x7F, 0x8C, 0xEB, 0x32, 0x39, 0xD3 }
};

#define PMIC_VER_NOT_AVAILABLE  0x7FFFFFFFU
#define PMIC_VER_SELECTOR_INFO  7

#define PMICSTUB_TAG "[PMICSTUB] "

typedef struct {
  UINTN                                        Reserved;
  EFI_STATUS (EFIAPI *GetInfo) (UINTN Selector, UINT32 *Out);
} PMIC_VER_IFACE;

STATIC
EFI_STATUS
EFIAPI
PmicVerGetInfo (
  IN  UINTN   Selector,
  OUT UINT32  *Out
  )
{
  DEBUG ((DEBUG_ERROR, PMICSTUB_TAG "GetInfo selector=%d\n", (UINT32)Selector));
  if (Out == NULL) {
    return EFI_INVALID_PARAMETER;
  }

  *Out = PMIC_VER_NOT_AVAILABLE;
  return EFI_SUCCESS;
}

STATIC PMIC_VER_IFACE  mPmicVerIfc = {
  0,
  PmicVerGetInfo
};

EFI_STATUS
EFIAPI
VermeerPmicVerStubDxeEntry (
  IN EFI_HANDLE        ImageHandle,
  IN EFI_SYSTEM_TABLE  *SystemTable
  )
{
  EFI_STATUS  Status;
  EFI_HANDLE  Handle;

  Handle = NULL;
  Status = gBS->InstallMultipleProtocolInterfaces (
                  &Handle,
                  (EFI_GUID *)&mPmicVerGuid,
                  &mPmicVerIfc,
                  NULL
                  );
  DEBUG ((DEBUG_ERROR, PMICSTUB_TAG "install pmic-ver stub -> %r\n", Status));
  return EFI_SUCCESS;
}