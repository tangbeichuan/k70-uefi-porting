#!/bin/bash
# keys147: 扫描 USB device-mode 相关驱动（UsbfnDwc3Dxe / UsbDeviceDxe / UsbMsdDxe / UsbInitDxe / UsbBusDxe）
set -u
B=/root/k70/uefi/Binaries/vermeer/QcomPkg/Drivers
OUT=/tmp/u147
mkdir -p $OUT

echo "########## INF PE32 selection ##########"
for n in UsbfnDwc3Dxe UsbDeviceDxe UsbMsdDxe UsbInitDxe UsbConfigDxe UsbBusDxe UsbPwrCtrlDxe; do
  d=$B/$n
  if [ -d "$d" ]; then
    echo "--- $n ---"
    ls -l "$d" | sed 's/^/    /'
    for inf in "$d"/*.inf; do
      [ -f "$inf" ] || continue
      echo "  INF $(basename $inf):"
      grep -E "PE32\||DXE_DEPEX|FILE_GUID|ENTRY_POINT|Depex" "$inf" | sed 's/^/      /'
    done
  else
    echo "--- $n : NO DIR ---"
  fi
done

echo
echo "########## headers ##########"
for n in UsbfnDwc3Dxe UsbDeviceDxe UsbMsdDxe UsbInitDxe UsbBusDxe; do
  d=$B/$n
  [ -d "$d" ] || continue
  f=$(ls "$d"/*.patched.efi 2>/dev/null | head -1)
  [ -z "$f" ] && f=$(ls "$d"/*.efi 2>/dev/null | head -1)
  [ -z "$f" ] && continue
  echo "=== $n : $(basename $f) ($(stat -c %s "$f") B) ==="
  llvm-readobj --file-headers --sections "$f" > $OUT/$n.hdr
  llvm-objdump -d "$f" > $OUT/$n.asm
  strings -t x -n 4 "$f" > $OUT/$n.str
  echo "  entrypoint/sections:"
  grep -E "AddressOfEntryPoint|ImageBase|Name: .text|Name: .data|VirtualAddress|VirtualSize|Size:" $OUT/$n.hdr | head -20 | sed 's/^/    /'
  echo "  GUID 常量 (uuid 形态):"
  grep -oE "[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}" $OUT/$n.str | sort | uniq -c | sort -rn | head -10 | sed 's/^/    /'
done

echo
echo "########## strings: USB device mode 关键串 ##########"
for n in UsbfnDwc3Dxe UsbDeviceDxe UsbMsdDxe UsbInitDxe UsbBusDxe; do
  [ -f $OUT/$n.str ] || continue
  echo "=== $n ==="
  grep -aiE "usb_shared|dwc3|phy_|_phy|vbus|pll|utmi|device_?init|DeviceInit|Run|ConfigProtocol|Msd|Mass|BlockIo|enumerat|connect|role|Lane|clock|reset|dtb|DTB|node" $OUT/$n.str | head -100 | sed 's/^/  /'
done
