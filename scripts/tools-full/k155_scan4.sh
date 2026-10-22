#!/usr/bin/env bash
python3 - <<'PY'
import struct, glob
paths = [
 "/root/k70/uefi/Binaries/vermeer/QcomPkg/Drivers/ClockDxe/ClockDxe.efi",
 "/root/k70/uefi/Binaries/vermeer/QcomPkg/Drivers/UsbConfigDxe/UsbConfigDxe.efi",
 "/root/k70/uefi/Binaries/vermeer/QcomPkg/Drivers/UsbfnDwc3Dxe/UsbfnDwc3Dxe.efi",
 "/root/k70/uefi/Binaries/vermeer/QcomPkg/Drivers/UsbDeviceDxe/UsbDeviceDxe.efi",
 "/root/k70/uefi/Binaries/vermeer/QcomPkg/Drivers/UsbInitDxe/UsbInitDxe.efi",
]
for p in paths:
    b = open(p, 'rb').read()
    name = p.split('/')[-1]
    hits = []
    # search full-address forms 0x0010F000..0x0010F0FF and 0x0010F000 block
    for off in range(0, len(b) - 4):
        v = struct.unpack_from("<I", b, off)[0]
        if 0x0010F000 <= v <= 0x0010F0FF:
            hits.append((off, v))
            if len(hits) > 40: break
    print(f"--- {name}: {len(hits)} full-addr GCC-USB hits")
    for off, v in hits[:20]:
        print(f"    file 0x{off:x}: 0x{v:08x}")
PY
echo
echo "=== _refs 0072 GCC section ==="
sed -n '40,80p' /mnt/d/本地项目-01/_refs/ios-vermeer-lab/xnu/patches/0072-sweet-usb-probe.patch
