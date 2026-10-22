#!/usr/bin/env bash
# What do the skeleton's RAW.inc references look like?
SK=/mnt/d/本地项目-01/_k70port_extract/k70-port/skeleton/Platforms/Xiaomi/vermeerPkg/Include
echo "===== RAW.inc first 60 lines ====="
sed -n '1,60p' "$SK/RAW.inc"
echo
echo "===== distinct Binaries paths in RAW.inc ====="
grep -o 'Binaries/[^ ]*' "$SK/RAW.inc" | sort | uniq -c | sort -rn | head -20
echo
echo "===== APRIORI.inc: non-Binaries lines (module order) ====="
grep -vn 'Binaries\|^#\|^$' "$SK/APRIORI.inc" | head -40
