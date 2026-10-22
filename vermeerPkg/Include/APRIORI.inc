APRIORI DXE {
  INF MdeModulePkg/Core/Dxe/DxeMain.inf
  INF MdeModulePkg/Universal/PCD/Dxe/Pcd.inf

  !if $(VERMEER_VENDOR_HW) == 1
  INF Binaries/vermeer/QcomPkg/Drivers/EnvDxe/EnvDxe.inf
  !endif

  INF MdeModulePkg/Universal/ReportStatusCodeRouter/RuntimeDxe/ReportStatusCodeRouterRuntimeDxe.inf
  INF MdeModulePkg/Universal/StatusCodeHandler/RuntimeDxe/StatusCodeHandlerRuntimeDxe.inf
  INF MdeModulePkg/Core/RuntimeDxe/RuntimeDxe.inf
  INF ArmPkg/Drivers/CpuDxe/CpuDxe.inf
  INF ArmPkg/Drivers/ArmGicDxe/ArmGicDxe.inf
  INF EmbeddedPkg/MetronomeDxe/MetronomeDxe.inf
  INF ArmPkg/Drivers/TimerDxe/TimerDxe.inf

  !if $(VERMEER_VENDOR_HW) == 1
  INF Binaries/vermeer/QcomPkg/Drivers/SmemDxe/SmemDxe.inf
  !endif
  !if $(VERMEER_VENDOR_HW) == 1
  INF Binaries/vermeer/QcomPkg/Drivers/DALSYSDxe/DALSYSDxe.inf
  !endif
  !if $(VERMEER_VENDOR_HW) == 1
  INF Binaries/vermeer/QcomPkg/Drivers/HWIODxe/HWIODxe.inf
  !endif
  !if $(VERMEER_VENDOR_HW) == 1
  INF Binaries/vermeer/QcomPkg/Drivers/ChipInfoDxe/ChipInfoDxe.inf
  !endif
  !if $(VERMEER_VENDOR_HW) == 1
  INF Binaries/vermeer/QcomPkg/Drivers/PlatformInfoDxe/PlatformInfoDxe.inf
  !endif
  !if $(VERMEER_VENDOR_HW) == 1
  INF Binaries/vermeer/QcomPkg/Drivers/ProjectInfoDxe/ProjectInfoDxe.inf
  !endif
  !if $(VERMEER_VENDOR_HW) == 1
# [keys70-hard]   INF Binaries/vermeer/QcomPkg/Drivers/HALIOMMUDxe/HALIOMMUDxe.inf
  !endif
  !if $(VERMEER_VENDOR_HW) == 1
  INF Binaries/vermeer/QcomPkg/Drivers/ULogDxe/ULogDxe.inf
  !endif
  !if $(VERMEER_VENDOR_HW) == 1
  INF Binaries/vermeer/QcomPkg/Drivers/IPCCDxe/IPCCDxe.inf
  !endif
  !if $(VERMEER_VENDOR_HW) == 1
  INF Binaries/vermeer/QcomPkg/Drivers/GLinkDxe/GLinkDxe.inf
  !endif
  !if $(VERMEER_VENDOR_HW) == 1
  INF Binaries/vermeer/QcomPkg/Drivers/CmdDbDxe/CmdDbDxe.inf
  !endif
  !if $(VERMEER_VENDOR_HW) == 1
  INF Binaries/vermeer/QcomPkg/Drivers/PwrUtilsDxe/PwrUtilsDxe.inf
  !endif
  !if $(VERMEER_VENDOR_HW) == 1
  INF Binaries/vermeer/QcomPkg/Drivers/NpaDxe/NpaDxe.inf
  !endif
  !if $(VERMEER_VENDOR_HW) == 1
  INF Binaries/vermeer/QcomPkg/Drivers/RpmhDxe/RpmhDxe.inf
  !endif
  !if $(VERMEER_VENDOR_HW) == 1
  INF Binaries/vermeer/QcomPkg/Drivers/VcsDxe/VcsDxe.inf
  !endif
  !if $(VERMEER_VENDOR_HW) == 1
# [keys47-drop]   INF Binaries/vermeer/QcomPkg/Drivers/ClockDxe/ClockDxe.inf
  !endif
  !if $(VERMEER_VENDOR_HW) == 1
  INF Binaries/vermeer/QcomPkg/Drivers/ICBDxe/ICBDxe.inf
  !endif
  !if $(VERMEER_VENDOR_HW) == 1
  INF Binaries/vermeer/QcomPkg/Drivers/ShmBridgeDxe/ShmBridgeDxeLA.inf
  !endif
  !if $(VERMEER_VENDOR_HW) == 1
# [keys47-drop]   INF Binaries/vermeer/QcomPkg/Drivers/TzDxe/ScmDxeCompat.inf
  !endif
  !if $(VERMEER_VENDOR_HW) == 1
  INF Binaries/vermeer/QcomPkg/Drivers/TLMMDxe/TLMMDxe.inf
  !endif
  !if $(VERMEER_VENDOR_HW) == 1
  INF Binaries/vermeer/QcomPkg/Drivers/I2CDxe/I2CDxe.inf
  !endif
  !if $(VERMEER_VENDOR_HW) == 1
  INF Binaries/vermeer/QcomPkg/Drivers/SPMIDxe/SPMIDxe.inf
  !endif

  INF MdeModulePkg/Universal/ResetSystemRuntimeDxe/ResetSystemRuntimeDxe.inf
  INF MdeModulePkg/Universal/Disk/DiskIoDxe/DiskIoDxe.inf
  INF MdeModulePkg/Universal/Disk/PartitionDxe/PartitionDxe.inf
  INF MdeModulePkg/Universal/Disk/UnicodeCollation/EnglishDxe/EnglishDxe.inf

  !if $(VERMEER_VENDOR_HW) == 1
# [keys47-drop]   INF Binaries/vermeer/QcomPkg/Drivers/SdccDxe/SdccDxe.inf
  !endif
  !if $(VERMEER_VENDOR_HW) == 1
  INF Binaries/vermeer/QcomPkg/Drivers/UFSDxe/UFSDxe.inf
  !endif

  INF FatPkg/EnhancedFatDxe/Fat.inf

  !if $(VERMEER_VENDOR_HW) == 1
  INF Binaries/vermeer/QcomPkg/Drivers/PmicDxe/PmicDxeLa.inf
  !endif
  !if $(VERMEER_VENDOR_HW) == 1
# [keys47-drop]   INF Binaries/vermeer/QcomPkg/Drivers/TzDxe/TzDxeLA.inf
  !endif

  INF MdeModulePkg/Universal/Variable/RuntimeDxe/VariableRuntimeDxe.inf

  !if $(VERMEER_VENDOR_HW) == 1
# [keys47-drop]   INF Binaries/vermeer/QcomPkg/Drivers/DDRInfoDxe/DDRInfoDxe.inf
  !endif
  !if $(VERMEER_VENDOR_HW) == 1
# [keys47-drop]   INF Binaries/vermeer/QcomPkg/Drivers/FeatureEnablerDxe/FeatureEnablerDxe.inf
  !endif

!if $(USE_CUSTOM_DISPLAY_DRIVER) == 1
# [keys47-drop]   INF Binaries/vermeer/QcomPkg/Drivers/DisplayDxe/DisplayDxe.inf
!else
!endif

  !if $(VERMEER_VENDOR_HW) == 1
# [keys47-drop]   INF Binaries/vermeer/QcomPkg/Drivers/PILProxyDxe/PILProxyDxe.inf
  !endif
  !if $(VERMEER_VENDOR_HW) == 1
# [keys47-drop]   INF Binaries/vermeer/QcomPkg/Drivers/PILDxe/PILDxe.inf
  !endif
  !if $(VERMEER_VENDOR_HW) == 1
# [keys47-drop]   INF Binaries/vermeer/QcomPkg/Drivers/SPSSDxe/SPSSDxe.inf
  !endif

  INF MdeModulePkg/Universal/WatchdogTimerDxe/WatchdogTimer.inf
  INF MdeModulePkg/Universal/SecurityStubDxe/SecurityStubDxe.inf
  INF EmbeddedPkg/EmbeddedMonotonicCounter/EmbeddedMonotonicCounter.inf
  INF EmbeddedPkg/RealTimeClockRuntimeDxe/RealTimeClockRuntimeDxe.inf
  INF MdeModulePkg/Universal/PrintDxe/PrintDxe.inf
  INF MdeModulePkg/Universal/DevicePathDxe/DevicePathDxe.inf
  INF MdeModulePkg/Universal/CapsuleRuntimeDxe/CapsuleRuntimeDxe.inf
  INF MdeModulePkg/Universal/HiiDatabaseDxe/HiiDatabaseDxe.inf
  INF MdeModulePkg/Universal/BdsDxe/BdsDxe.inf

  !if $(VERMEER_VENDOR_HW) == 1
  INF Binaries/vermeer/QcomPkg/Drivers/SPIDxe/SPIDxe.inf
  !endif
  !if $(VERMEER_VENDOR_HW) == 1
  INF Binaries/vermeer/QcomPkg/Drivers/PmicGlinkDxe/PmicGlinkDxe.inf
  !endif
  !if $(VERMEER_VENDOR_HW) == 1
  INF Binaries/vermeer/QcomPkg/Drivers/UsbPwrCtrlDxe/UsbPwrCtrlDxe.inf
  !endif
  !if $(VERMEER_VENDOR_HW) == 1
# [keys47-drop]   INF Binaries/vermeer/QcomPkg/Drivers/QcomChargerDxe/QcomChargerDxeLA.inf
  !endif
  !if $(VERMEER_VENDOR_HW) == 1
# [keys47-drop]   INF Binaries/vermeer/QcomPkg/Drivers/ChargerExDxe/ChargerExDxe.inf
  !endif
  !if $(VERMEER_VENDOR_HW) == 1
  !endif
  !if $(VERMEER_VENDOR_HW) == 1
  INF Binaries/vermeer/QcomPkg/Drivers/XhciPciEmulationDxe/XhciPciEmulationDxe.inf
  !endif
  !if $(VERMEER_VENDOR_HW) == 1
  INF Binaries/vermeer/QcomPkg/Drivers/XhciDxe/XhciDxe.inf
  !endif

  INF MdeModulePkg/Bus/Usb/UsbBusDxe/UsbBusDxe.inf
  INF MdeModulePkg/Bus/Usb/UsbKbDxe/UsbKbDxe.inf
  INF MdeModulePkg/Bus/Usb/UsbMassStorageDxe/UsbMassStorageDxe.inf

  !if $(VERMEER_VENDOR_HW) == 1
  INF Binaries/vermeer/QcomPkg/Drivers/UsbMsdDxe/UsbMsdDxe.inf
  !endif
  !if $(VERMEER_VENDOR_HW) == 1
  !endif
  !if $(VERMEER_VENDOR_HW) == 1
  INF Binaries/vermeer/QcomPkg/Drivers/UsbConfigDxe/UsbConfigDxe.inf
  !endif
  !if $(VERMEER_VENDOR_HW) == 1
  INF Binaries/vermeer/QcomPkg/Drivers/ButtonsDxe/ButtonsDxe.inf
  !endif
  !if $(VERMEER_VENDOR_HW) == 1
# [keys47-drop]   INF Binaries/vermeer/QcomPkg/Drivers/TsensDxe/TsensDxe.inf
  !endif
  !if $(VERMEER_VENDOR_HW) == 1
# [keys47-drop]   INF Binaries/vermeer/QcomPkg/Drivers/LimitsDxe/LimitsDxe.inf
  !endif
!if $(USE_CUSTOM_DISPLAY_DRIVER) == 1
  INF Binaries/vermeer/QcomPkg/Drivers/CPRDxe/CPRDxe.inf
!endif
  !if $(VERMEER_VENDOR_HW) == 1
  INF Binaries/vermeer/QcomPkg/Drivers/GpiDxe/GpiDxe.inf
  !endif
  !if $(VERMEER_VENDOR_HW) == 1
# [keys47-drop]   INF Binaries/vermeer/QcomPkg/Drivers/UCDxe/UCDxe.inf
  !endif
  !if $(VERMEER_VENDOR_HW) == 1
# [keys47-drop]   INF Binaries/vermeer/QcomPkg/Drivers/RNGDxe/RngDxe.inf
  !endif

  INF EmbeddedPkg/SimpleTextInOutSerial/SimpleTextInOutSerial.inf
  INF MdeModulePkg/Universal/Console/ConPlatformDxe/ConPlatformDxe.inf
  INF MdeModulePkg/Universal/Console/ConSplitterDxe/ConSplitterDxe.inf
  INF MdeModulePkg/Universal/Console/GraphicsConsoleDxe/GraphicsConsoleDxe.inf

  !if $(VERMEER_VENDOR_HW) == 1
  INF Binaries/vermeer/QcomPkg/Drivers/RscDxe/RscDxe.inf
  !endif
}
# [keys123] INF Binaries/vermeer/QcomPkg/Drivers/UsbfnDwc3Dxe/UsbfnDwc3Dxe.inf
# [keys123] INF Binaries/vermeer/QcomPkg/Drivers/UsbDeviceDxe/UsbDeviceDxe.inf
INF vermeerPkg/Drivers/VermeerMenuDxe/VermeerMenuDxe.inf
