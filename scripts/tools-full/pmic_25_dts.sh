#!/bin/bash
DTB=/root/k70/uefi/Platforms/Xiaomi/vermeerPkg/FdtBlob/xbl_ufs.dtb
ls -la "$DTB"
dtc -I dtb -O dts "$DTB" -o /tmp/xbl_ufs.dts 2>/tmp/dtc.err; echo "dtc rc=$?"; head -3 /tmp/dtc.err
wc -l /tmp/xbl_ufs.dts
echo '--- top-level nodes'
grep -n '^\t[A-Za-z]' /tmp/xbl_ufs.dts | head -40
echo '--- does /sw exist?'
grep -n 'sw {' /tmp/xbl_ufs.dts | head
echo '--- pmic/vadc mentions'
grep -n -i 'pmic\|vadc\|adc' /tmp/xbl_ufs.dts | head -40
