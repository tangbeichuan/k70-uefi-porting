#include <Uefi.h>
#include <Library/UefiBootServicesTableLib.h>
#include <Library/DebugLib.h>
#include <Library/BaseLib.h>

//
// Qualcomm SMMU (IOMMU) 协议 GUID —— 从 UFSDxe.efi 里 LocateProtocol 的 GUID 提取
//   UFSDxe.efi 0x1773c: adrp x0, ..; add x0, x0, #0x258  -> 0x1C258
//   54B6D3B4-5D33-4F91-8600-6C41D5DEB19A
//
STATIC CONST EFI_GUID mSmmuProtoGuid = {
  0x54b6d3b4, 0x5d33, 0x4f91, { 0x86, 0x00, 0x6c, 0x41, 0xd5, 0xde, 0xb1, 0x9a }
};

#define SMMU_STUB_SLOTS  64

STATIC UINTN mCalls = 0;

STATIC
EFI_STATUS
EFIAPI
SmmuStubCall (
  VOID
  )
{
  mCalls++;
  if (mCalls <= 16) {
    DEBUG ((DEBUG_ERROR, "[SMMUSTUB] slot call #%ld\n", mCalls));
  }
  return EFI_SUCCESS;
}

STATIC UINT64 mSmmuTable[SMMU_STUB_SLOTS];

EFI_STATUS
EFIAPI
VermeerSmmuStubDxeEntry (
  IN EFI_HANDLE        ImageHandle,
  IN EFI_SYSTEM_TABLE  *SystemTable
  )
{
  EFI_STATUS  Status;
  EFI_HANDLE  Handle;
  UINTN       Index;

  for (Index = 0; Index < SMMU_STUB_SLOTS; Index++) {
    mSmmuTable[Index] = (UINT64)(UINTN)SmmuStubCall;
  }

  Handle = NULL;
  Status = gBS->InstallMultipleProtocolInterfaces (
                  &Handle,
                  (EFI_GUID *)&mSmmuProtoGuid,
                  mSmmuTable,
                  NULL
                  );
  DEBUG ((DEBUG_ERROR, "[SMMUSTUB] install smmu stub ifc=0x%lx -> %r\n",
          (UINT64)(UINTN)mSmmuTable, Status));
  return Status;
}