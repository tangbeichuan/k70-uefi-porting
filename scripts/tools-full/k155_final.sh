#!/usr/bin/env bash
set -u
echo "--- MemoryMapLib state (expect GCC=0, USB=1) ---"
grep -c '"GCC"' /root/k70/uefi/Platforms/Xiaomi/vermeerPkg/Library/MemoryMapLib/MemoryMapLib.c || true
grep -c '"USB"' /root/k70/uefi/Platforms/Xiaomi/vermeerPkg/Library/MemoryMapLib/MemoryMapLib.c || true
grep -n 'GCC\|USB' /root/k70/uefi/Platforms/Xiaomi/vermeerPkg/Library/MemoryMapLib/MemoryMapLib.c | sed -n '1,4p'
echo "--- deliverables ---"
cd /mnt/d/本地项目-01
sha256sum K70-UEFI-build/K70-keys155-GCC-READ.img K70-UEFI-build/Mu-vermeer-keys155.img _k70port_extract/qemu-fw/SILICIUM_UEFI-keys155.fd
ls -l _tools/KEYS155_REPORT.md
echo "--- report tail ---"
wc -l _tools/KEYS155_REPORT.md
