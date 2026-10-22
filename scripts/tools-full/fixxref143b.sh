#!/bin/bash
X=/root/k70/uefi/Build/vermeerPkg/DEBUG_CLANGPDB/FV/Guid.xref
ls -l "$X"
for p in HALIOMMU AcpiTableDxe UsbConfigDxe UsbInitDxe UsbMsdDxe UsbfnDwc3Dxe UsbDeviceDxe VermeerPmicVerStubDxe PmicDxe VermeerDtbExtnDxe VermeerLogDiskDxe VermeerMenuDxe; do
  L=$(grep -i " $p\$" "$X" | head -1)
  [ -z "$L" ] && L=$(grep -i "$p" "$X" | head -1)
  echo "  ${L:----- $p}"
done
