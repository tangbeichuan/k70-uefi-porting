#!/bin/bash
Q=/mnt/d/本地项目-01/_k70port_extract/qemu-fw
T=/mnt/d/本地项目-01/_tools
echo "##### LogDisk module markers #####"
for fd in keys149 keys151 keys151b; do
  echo "--- $fd ---"
  python3 $T/k151_str.py $Q/SILICIUM_UEFI-$fd.fd 9c5e7a31-4b28-4f6d-8a19-2d7c6e5b3a84 \
    "[USBDIAG] DWC3[%a] dec" "DWC3 late run" "already running, no action" "probe end" "volume ready"
done
echo "##### DtbExtn module markers #####"
for fd in keys149 keys151 keys151b; do
  echo "--- $fd ---"
  python3 $T/k151_str.py $Q/SILICIUM_UEFI-$fd.fd 5b21e7c4-3d18-4f6a-9a20-8c7e51fd42b9 \
    "[VBUS] dec" "[VBUS] before" "GSNPSID=" "selftest vadc" "vermeer dtb-extn provider"
done
echo "##### source greps #####"
grep -c "USBDIAG" /mnt/d/本地项目-01/_tools/VermeerLogDiskDxe.c || true
grep -n "DWC3 late run\|UsbDiagEnsureRun\|VERMEER_USB_DIAG" /mnt/d/本地项目-01/_tools/VermeerLogDiskDxe.c | head -10
grep -n "\[VBUS\] dec\|GSNPSID" /mnt/d/本地项目-01/_k70port_extract/port-drivers/VermeerDtbExtnDxe/VermeerDtbExtnDxe.c | head -10
ls -l /mnt/d/本地项目-01/_tools/VermeerLogDiskDxe.c /mnt/d/本地项目-01/_k70port_extract/port-drivers/VermeerDtbExtnDxe/VermeerDtbExtnDxe.c
ls -l /root/k70/uefi/Platforms/Xiaomi/vermeerPkg/Drivers/VermeerLogDiskDxe/VermeerLogDiskDxe.c /root/k70/uefi/Platforms/Xiaomi/vermeerPkg/Drivers/VermeerDtbExtnDxe/VermeerDtbExtnDxe.c 2>/dev/null
sha256sum /mnt/d/本地项目-01/_tools/VermeerLogDiskDxe.c /root/k70/uefi/Platforms/Xiaomi/vermeerPkg/Drivers/VermeerLogDiskDxe/VermeerLogDiskDxe.c 2>/dev/null
