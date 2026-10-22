#!/bin/bash
N=/root/k70/uefi/Platforms/Xiaomi/nuwaPkg
echo "=== nuwa APRIORI: DtPlatform / Hii / UFS positions ==="
grep -n "DtPlatform\|HiiDatabase\|UFSDxe\|DxeMain\|Pcd.inf\|BdsDxe" $N/Include/APRIORI.inc
echo
echo "=== nuwa DXE.inc: DtPlatform ==="
grep -n -B3 -A3 "DtPlatform" $N/Include/DXE.inc
echo
echo "=== nuwa dsc: DtPlatform component ==="
grep -n "DtPlatform\|DtPlatformDtbLoader" $N/nuwa.dsc
echo
echo "=== DtPlatformDxe.c tail (what it installs) ==="
sed -n '140,240p' /root/k70/uefi/Mu_Basecore/EmbeddedPkg/Drivers/DtPlatformDxe/DtPlatformDxe.c
