#!/usr/bin/env bash
set +e
echo "=== grep UsbConfigDxe in build_keys140.sh / run_keys140.sh ==="
grep -n -i "usbconfig" /mnt/d/本地项目-01/_tools/build_keys140.sh /mnt/d/本地项目-01/_tools/run_keys140.sh 2>/dev/null
echo
echo "=== DROP block in build_keys140.sh (search 'usbconfig' context) ==="
grep -n -B6 -A20 'usbconfig' /mnt/d/本地项目-01/_tools/build_keys140.sh 2>/dev/null | head -80
echo
echo "=== build log possibilities ==="
ls -lt /root/k70/uefi/*.log /root/k70/uefi/Build/vermeerPkg/DEBUG_CLANGPDB/*.log 2>/dev/null | head
ls -lt /tmp/*.log /tmp/b*.log 2>/dev/null | head
echo
echo "=== dsc components: how UsbMsdDxe / UsbfnDwc3Dxe / UsbConfigDxe appear ==="
grep -n -E "UsbMsdDxe|UsbfnDwc3Dxe|UsbConfigDxe|UsbInitDxe|Extra\.dsc" /root/k70/uefi/Platforms/Xiaomi/vermeerPkg/vermeer.dsc
echo
echo "=== Extra.dsc.inc / Extra.fdf.inc ==="
ls -l /root/k70/uefi/Binaries/vermeer/QcomPkg/Extra.dsc.inc /root/k70/uefi/Binaries/vermeer/QcomPkg/Extra.fdf.inc 2>/dev/null
grep -n -i -E "UsbConfigDxe|UsbMsdDxe|UsbfnDwc3Dxe" /root/k70/uefi/Binaries/vermeer/QcomPkg/Extra.dsc.inc /root/k70/uefi/Binaries/vermeer/QcomPkg/Extra.fdf.inc 2>/dev/null
