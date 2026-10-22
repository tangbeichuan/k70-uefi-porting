#!/usr/bin/env bash
set +e
echo "=== running builds ==="
ps aux > /tmp/pslist.txt
grep -E "build_uefi|build_keys|run_keys" /tmp/pslist.txt | grep -v grep
echo "=== pkg state ==="
PKG=/root/k70/uefi/Platforms/Xiaomi/vermeerPkg
echo -n "keys138-drop markers in dsc: "; grep -c "keys138-drop" "$PKG/vermeer.dsc"
echo -n "nopmic markers in APRIORI: "; grep -c "keys138-nopmic" "$PKG/Include/APRIORI.inc"
echo -n "DtbExtn in dsc: "; grep -c "VermeerDtbExtnDxe" "$PKG/vermeer.dsc"
echo -n "DtbExtn in APRIORI: "; grep -c "VermeerDtbExtnDxe" "$PKG/Include/APRIORI.inc"
echo -n "DtbExtn in fdf: "; grep -c "VermeerDtbExtnDxe" "$PKG/vermeer.fdf"
echo "=== pkg copy vs port-drivers source ==="
sha256sum "$PKG/Drivers/VermeerDtbExtnDxe/VermeerDtbExtnDxe.c" /mnt/d/本地项目-01/_k70port_extract/port-drivers/VermeerDtbExtnDxe/VermeerDtbExtnDxe.c
echo "=== pkg copy slot sizes (A3, 512) ==="
grep -c "A3, 512)" "$PKG/Drivers/VermeerDtbExtnDxe/VermeerDtbExtnDxe.c"
echo "=== last build log tail ==="
tail -5 /tmp/b138.log 2>/dev/null
