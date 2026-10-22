/** @file
  VermeerUsbVbusDxe - force the Qualcomm QSCRATCH "VBUS valid" override so the
  DWC3 device controller pulls up D+ and enumerates on the host.

  Ported from the xyyyds0106/ios-vermeer-lab finding (xnu patch
  0074-sweet-usb-vbus-override.patch): the controller only connects while it
  sees a valid VBUS session; Linux dwc3-qcom forces this in software
  (dwc3_qcom_vbus_override_enable) when the charger reports a cable.

  QSCRATCH (core base 0x0A600000 + 0xF8800 = 0x0A6F8800, inside the "USB"
  region already mapped by MemoryMapLib):
    +0x08 GENERAL_CFG
    +0x10 HS_PHY_CTRL   bit20 UTMI_OTG_VBUS_VALID, bit28 SW_SESSVLD_SEL
    +0x30 SS_PHY_CTRL   bit24 LANE0_PWR_PRESENT
**/

#include <Uefi.h>
#include <Library/UefiLib.h>
#include <Library/BaseLib.h>
#include <Library/DebugLib.h>

#define QSCRATCH_BASE        0x0A6F8800ULL
#define QSCRATCH_GENERAL_CFG 0x08U
#define QSCRATCH_HS_PHY_CTRL 0x10U
#define QSCRATCH_SS_PHY_CTRL 0x30U
#define UTMI_OTG_VBUS_VALID  (1U << 20)
#define SW_SESSVLD_SEL       (1U << 28)
#define LANE0_PWR_PRESENT    (1U << 24)

#define DWC3_BASE            0x0A600000ULL
#define DWC3_GCTL            0xC110U
#define DWC3_DCTL            0xC700U
#define DWC3_DSTS            0xC704U

STATIC
UINT32
Rd32 (
  IN UINT64 Addr
  )
{
  return *(volatile UINT32 *)(UINTN)Addr;
}

STATIC
VOID
Wr32 (
  IN UINT64 Addr,
  IN UINT32 Val
  )
{
  *(volatile UINT32 *)(UINTN)Addr = Val;
  MemoryFence ();
}

EFI_STATUS
EFIAPI
VermeerUsbVbusDxeEntry (
  IN EFI_HANDLE        ImageHandle,
  IN EFI_SYSTEM_TABLE  *SystemTable
  )
{
  UINT32 Hs, Ss, Gen, Gctl, Dctl, Dsts;

  Gctl = Rd32 (DWC3_BASE + DWC3_GCTL);
  Dctl = Rd32 (DWC3_BASE + DWC3_DCTL);
  Dsts = Rd32 (DWC3_BASE + DWC3_DSTS);
  Gen  = Rd32 (QSCRATCH_BASE + QSCRATCH_GENERAL_CFG);
  Hs   = Rd32 (QSCRATCH_BASE + QSCRATCH_HS_PHY_CTRL);
  Ss   = Rd32 (QSCRATCH_BASE + QSCRATCH_SS_PHY_CTRL);

  DEBUG ((
    DEBUG_ERROR,
    "[VBUS] before: GCTL=%08x DCTL=%08x DSTS=%08x GEN=%08x HS=%08x SS=%08x\n",
    Gctl, Dctl, Dsts, Gen, Hs, Ss
    ));

  Wr32 (QSCRATCH_BASE + QSCRATCH_HS_PHY_CTRL, Hs | UTMI_OTG_VBUS_VALID | SW_SESSVLD_SEL);
  Wr32 (QSCRATCH_BASE + QSCRATCH_SS_PHY_CTRL, Ss | LANE0_PWR_PRESENT);

  Hs = Rd32 (QSCRATCH_BASE + QSCRATCH_HS_PHY_CTRL);
  Ss = Rd32 (QSCRATCH_BASE + QSCRATCH_SS_PHY_CTRL);
  Dctl = Rd32 (DWC3_BASE + DWC3_DCTL);
  Dsts = Rd32 (DWC3_BASE + DWC3_DSTS);

  DEBUG ((
    DEBUG_ERROR,
    "[VBUS] after : HS=%08x SS=%08x DCTL=%08x DSTS=%08x\n",
    Hs, Ss, Dctl, Dsts
    ));

  return EFI_SUCCESS;
}