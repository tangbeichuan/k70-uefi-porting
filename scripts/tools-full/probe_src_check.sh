#!/bin/bash
P=/root/k70/uefi/Platforms/Xiaomi/vermeerPkg/Drivers/VermeerDtDumpDxe/VermeerDtDumpDxe.c
ls -l "$P"
echo "--- markers ---"
grep -n 'ver scan done\|fdt scan done\|ScanWindowForVer\|ScanWindowForFdt\|re-probe' "$P"
echo "--- also the source of truth ---"
Q=/mnt/d/本地项目-01/_k70port_extract/port-drivers/VermeerDtDumpDxe/VermeerDtDumpDxe.c
ls -l "$Q"
grep -c 'ScanWindowForVer' "$Q"
