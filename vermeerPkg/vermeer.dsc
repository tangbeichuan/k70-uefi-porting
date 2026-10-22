##
#  Copyright (c) 2011 - 2022, ARM Limited. All rights reserved.
#  Copyright (c) 2014, Linaro Limited. All rights reserved.
#  Copyright (c) 2015 - 2020, Intel Corporation. All rights reserved.
#  Copyright (c) 2018, Bingxing Wang. All rights reserved.
#  Copyright (c) Microsoft Corporation.
#
#  SPDX-License-Identifier: BSD-2-Clause-Patent
##

################################################################################
#
# Defines Section - statements that will be processed to create a Makefile.
#
################################################################################
[Defines]
  PLATFORM_NAME                  = vermeer
  PLATFORM_GUID                  = 5B1D7C4A-9E3F-4B62-A1C8-7D2E6F0B9A31
  PLATFORM_VERSION               = 0.1
  DSC_SPECIFICATION              = 0x00010005
  OUTPUT_DIRECTORY               = Build/vermeerPkg
  SUPPORTED_ARCHITECTURES        = AARCH64
  BUILD_TARGETS                  = RELEASE|DEBUG
  SKUID_IDENTIFIER               = DEFAULT
  FLASH_DEFINITION               = vermeerPkg/vermeer.fdf
  USE_CUSTOM_DISPLAY_DRIVER      = 0

  #
  # 0 = Mu drivers only. The stage-1 display keeps scanning out, so the boot
  #     manager is visible without any vendor hardware driver.
  # 1 = also load the stock vendor hardware drivers (SMEM, clocks, RPMh, UFS,
  #     USB, charger, ...). Their initialization blanks the panel.
  #
  VERMEER_VENDOR_HW              = 1
  VERMEER_PAINT                   = 0
  VERMEER_VENDOR_INPUT           = 0
  VERMEER_KEYPROBE               = 1
  QEMU_BRINGUP                   = 0
  VERMEER_BANNER                 = 0

  #
  # 0 = SM8550-AB
  # 1 = SM8550-AC
  #
  SOC_TYPE                       = 0

!include KailuaPkg/KailuaPkg.dsc.inc

!if ($(USE_CUSTOM_DISPLAY_DRIVER) == 1) && ($(VERMEER_VENDOR_HW) == 0)
  !error The stock DisplayDxe chain needs VERMEER_VENDOR_HW = 1
!endif

[PcdsFixedAtBuild]
  #
  # DDR Memory
  #
  gArmTokenSpaceGuid.PcdSystemMemoryBase|0x80000000

  #
  # UEFI Stack
  #
  gArmPlatformTokenSpaceGuid.PcdCPUCoresStackBase|0xA760D000
  gArmPlatformTokenSpaceGuid.PcdCPUCorePrimaryStackSize|0x40000

  #
  # SMBIOS
  #
  gSiliciumPkgTokenSpaceGuid.PcdSmbiosSystemManufacturer|"Xiaomi"
  gSiliciumPkgTokenSpaceGuid.PcdSmbiosSystemModel|"Redmi K70"
  gSiliciumPkgTokenSpaceGuid.PcdSmbiosSystemRetailModel|"vermeer"
  gSiliciumPkgTokenSpaceGuid.PcdSmbiosSystemRetailSku|"K70_vermeer"
  gSiliciumPkgTokenSpaceGuid.PcdSmbiosSystemBoardModel|"Redmi K70"

  #
  # Simple Frame Buffer
  #
  gSiliciumPkgTokenSpaceGuid.PcdFrameBufferWidth|1440
  gSiliciumPkgTokenSpaceGuid.PcdFrameBufferHeight|3200
  gSiliciumPkgTokenSpaceGuid.PcdFrameBufferColorDepth|32

  #
  # Platform PEI
  #
  gQcomPkgTokenSpaceGuid.PcdPlatformType|"LA"

  #
  # Frame-buffer boot log (SiliciumPkg FrameBufferSerialPortLib). Without these
  # the DEBUG log draws nothing useful after SEC clears "Display Reserved".
  # Scale 3 gives roughly 56 lines on a 3200 px tall panel; the log wraps.
  #
  gSiliciumPkgTokenSpaceGuid.PcdFrameBufferFontScale|3
  gSiliciumPkgTokenSpaceGuid.PcdFrameBufferDelay|30000


[LibraryClasses]
  #
  # Memory Libraries
  #
  MemoryMapLib|vermeerPkg/Library/MemoryMapLib/MemoryMapLib.inf

  #
  # QCOM Libraries
  #
  ConfigurationMapLib|vermeerPkg/Library/ConfigurationMapLib/ConfigurationMapLib.inf


# --- QEMU bring-up overrides (never shipped; QEMU_BRINGUP defaults to 0) ------------------
!if $(QEMU_BRINGUP) == 1
[PcdsFixedAtBuild.common]
  gArmTokenSpaceGuid.PcdGicDistributorBase|0x08000000
  gArmTokenSpaceGuid.PcdGicRedistributorsBase|0x080A0000
  gArmTokenSpaceGuid.PcdArmArchTimerSecIntrNum|29
  gArmTokenSpaceGuid.PcdArmArchTimerIntrNum|30
  gEfiMdeModulePkgTokenSpaceGuid.PcdSerialRegisterBase|0x09000000
  gArmPlatformTokenSpaceGuid.PL011UartClkInHz|24000000
  gEfiMdePkgTokenSpaceGuid.PcdUartDefaultBaudRate|115200
  gEfiMdeModulePkgTokenSpaceGuid.PcdSerialBaudRate|115200
  gEfiMdeModulePkgTokenSpaceGuid.PcdSerialUseHardwareFlowControl|FALSE
  gEfiMdePkgTokenSpaceGuid.PcdUartDefaultReceiveFifoDepth|0

[LibraryClasses]
  SerialPortLib|ArmPlatformPkg/Library/PL011SerialPortLib/PL011SerialPortLib.inf
  PL011UartLib|ArmPlatformPkg/Library/PL011UartLib/PL011UartLib.inf
  PL011UartClockLib|ArmPlatformPkg/Library/PL011UartClockLib/PL011UartClockLib.inf

[BuildOptions]
  *_*_AARCH64_CC_FLAGS = -DQEMU_BRINGUP=1
!endif

# --- end of QEMU bring-up overrides -------------------------------------------------------

[Components]
  vermeerPkg/Drivers/VermeerUsbVbusDxe/VermeerUsbVbusDxe.inf

!if $(VERMEER_VENDOR_INPUT) == 1
  Binaries/vermeer/QcomPkg/Drivers/TzDxe/ScmDxeCompat.inf
  Binaries/vermeer/QcomPkg/Drivers/SPMIDxe/SPMIDxe.inf
  Binaries/vermeer/QcomPkg/Drivers/PmicGlinkDxe/PmicGlinkDxe.inf
  Binaries/vermeer/QcomPkg/Drivers/SmemDxe/SmemDxe.inf
  Binaries/vermeer/QcomPkg/Drivers/PmicDxe/PmicDxeLa.inf
  Binaries/vermeer/QcomPkg/Drivers/TLMMDxe/TLMMDxe.inf
  Binaries/vermeer/QcomPkg/Drivers/RpmhDxe/RpmhDxe.inf
  Binaries/vermeer/QcomPkg/Drivers/VcsDxe/VcsDxe.inf
  Binaries/vermeer/QcomPkg/Drivers/DALSYSDxe/DALSYSDxe.inf
  Binaries/vermeer/QcomPkg/Drivers/ButtonsDxe/ButtonsDxe.inf
!endif

!if $(VERMEER_KEYPROBE) == 1
  vermeerPkg/Drivers/VermeerKeyProbeDxe/VermeerKeyProbeDxe.inf
  vermeerPkg/Drivers/VermeerDtbExtnDxe/VermeerDtbExtnDxe.inf
  vermeerPkg/Drivers/VermeerMenuDxe/VermeerMenuDxe.inf
  vermeerPkg/Drivers/VermeerUfsMapDxe/VermeerUfsMapDxe.inf
  vermeerPkg/Drivers/VermeerSmmuStubDxe/VermeerSmmuStubDxe.inf
  vermeerPkg/Apps/VermeerStage2App/VermeerStage2App.inf
!endif

!if $(VERMEER_BANNER) == 1
  vermeerPkg/Drivers/VermeerBannerDxe/VermeerBannerDxe.inf
!endif

  #
  # ACPI Tables
  #
  #vermeer/AcpiTables.inf

!if $(VERMEER_PAINT) == 1
  vermeerPkg/Drivers/VermeerPaintDxe/VermeerPaintDxe.inf
!endif
  vermeerPkg/Drivers/VermeerLogDiskDxe/VermeerLogDiskDxe.inf
