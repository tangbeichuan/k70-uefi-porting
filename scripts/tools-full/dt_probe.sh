#!/bin/bash
cd /mnt/d/本地项目-01/_k70_pkg_1019/K70-UEFI-package/extracted || exit 1
echo "=== tools ==="
which dtc fdtdump 2>/dev/null || echo "no dtc"
for f in xbl_config_fdt_10168.dtb xbl_config_fdt_cb20.dtb; do
  echo "=== $f ($(stat -c%s $f) bytes) ==="
  if which dtc >/dev/null 2>&1; then
    dtc -I dtb -O dts -q "$f" -o "/tmp/$f.dts" 2>&1 | head -3
    echo "dts lines: $(wc -l < /tmp/$f.dts)"
    echo "-- nodes with ufs --"
    grep -n 'ufs' "/tmp/$f.dts" | head -20
    echo "-- pmic client nodes --"
    grep -n 'pmic/client\|ufs0_vcc\|ufs0_vdda' "/tmp/$f.dts" | head -10
    echo "-- top-level model/compatible --"
    head -20 "/tmp/$f.dts"
  fi
done
echo "=== compare with our vermeer dtb ==="
stat -c '%n %s' vermeer-live.dtb
