#!/bin/bash
echo "=== nuwa FdtBlob ==="
find /root/k70/uefi/Platforms/Xiaomi -name '*.dtb' 2>/dev/null | head -20
N=$(find /root/k70/uefi/Platforms/Xiaomi/nuwaPkg/FdtBlob -name '*.dtb' 2>/dev/null | head -1)
echo "nuwa blob: $N"
if [ -n "$N" ]; then
  ls -l "$N"
  dtc -I dtb -O dts -q "$N" -o /tmp/nuwa.dts 2>&1 | head -3
  echo "--- model/compatible ---"; head -8 /tmp/nuwa.dts
  echo "--- ufs nodes ---"; grep -n 'ufs' /tmp/nuwa.dts | head -12
  echo "--- init_speed_params ---"; grep -n 'init_speed_params\|fDeviceInitTimeoutUs' /tmp/nuwa.dts | head
fi
echo
echo "=== our vermeer FdtBlob ==="
ls -l /root/k70/uefi/Platforms/Xiaomi/vermeerPkg/FdtBlob/ 2>/dev/null
V=/root/k70/uefi/Platforms/Xiaomi/vermeerPkg/FdtBlob/sm8550-xiaomi-vermeer.dtb
if [ -f "$V" ]; then
  dtc -I dtb -O dts -q "$V" -o /tmp/vermeer.dts 2>&1 | head -3
  echo "--- model ---"; head -8 /tmp/vermeer.dts
  echo "--- ufs ---"; grep -n 'ufs' /tmp/vermeer.dts | head -10
fi
