#!/usr/bin/env bash
# How does sheng gate vendor drivers behind SHENG_VENDOR_HW?
cd /root/k70/uefi/Platforms/Xiaomi/shengPkg/Include || exit 1
for f in APRIORI.inc DXE.inc RAW.inc; do
  echo "===== $f ($(wc -l < "$f") lines) ====="
  grep -n '!if\|!else\|!endif\|Binaries' "$f" | head -50
  echo
done
echo "===== plain (non-conditional) Binaries refs in sheng DXE.inc ====="
grep -c 'Binaries' DXE.inc APRIORI.inc RAW.inc
echo
echo "===== how many Binaries refs in each vermeer skeleton inc ====="
cd /mnt/d/本地项目-01/_k70port_extract/k70-port/skeleton/Platforms/Xiaomi/vermeerPkg/Include || exit 1
grep -c 'Binaries' APRIORI.inc DXE.inc RAW.inc
echo
echo "===== any !if in vermeer incs? ====="
grep -n '!if\|!endif' APRIORI.inc DXE.inc RAW.inc | head -20
