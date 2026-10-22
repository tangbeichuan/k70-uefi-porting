#!/bin/bash
A=/root/k70/uefi/Platforms/Xiaomi/vermeerPkg/Include/APRIORI.inc
echo "=== lines ==="; wc -l "$A"
echo "=== EnvDxe / UFSDxe / probe lines with numbers ==="
grep -n "EnvDxe\|UFSDxe\|VermeerDtDumpDxe\|VermeerKeyProbeDxe\|Pcd.inf" "$A"
echo
echo "=== tail 25 ==="
tail -25 "$A"
