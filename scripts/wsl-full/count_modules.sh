#!/usr/bin/env bash
# Count and list the modules that were actually compiled into the FVMAIN.
set +e
LOG=/root/k70/build-default.log
grep -oE 'AARCH64/[^ ]*/([A-Za-z0-9_]+)/OUTPUT' "$LOG" 2>/dev/null | sed -E 's#/OUTPUT##' | awk -F/ '{print $NF}' | sort -u > /tmp/mods.txt
echo "modules compiled: $(wc -l < /tmp/mods.txt)"
echo
# also list the INF lines that are actually enabled in the fdf/includes
PKG=/root/k70/uefi/Platforms/Xiaomi/vermeerPkg
echo "=== enabled INF lines in the fdf (gates at VERMEER_VENDOR_HW=0) ==="
{
  grep -hE '^\s*INF ' "$PKG/vermeer.fdf"
  grep -hE '^\s*INF ' "$PKG/Include/APRIORI.inc" "$PKG/Include/DXE.inc" 2>/dev/null
} | sed -E 's/^\s*INF +//; s/#.*//' | grep -v '^\s*$' | sort | uniq -c | sort -rn | head -80
echo
echo "total INF lines (with duplicates across fdf/inc): $( { grep -hE '^\s*INF ' "$PKG/vermeer.fdf"; grep -hE '^\s*INF ' "$PKG/Include/APRIORI.inc" "$PKG/Include/DXE.inc"; } | wc -l )"
echo "unique IINFs: $( { grep -hE '^\s*INF ' "$PKG/vermeer.fdf"; grep -hE '^\s*INF ' "$PKG/Include/APRIORI.inc" "$PKG/Include/DXE.inc"; } | sed -E 's/^\s*INF +//' | sort -u | wc -l )"
