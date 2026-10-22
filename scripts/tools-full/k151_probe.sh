#!/bin/bash
PKG=/root/k70/uefi/Platforms/Xiaomi/vermeerPkg
echo "=== MemoryMapLib.c USB / 0x0A600000 rows ==="
grep -n 'USB\|0x0A600000\|0x0a600000\|0x0A6F8800' "$PKG/Library/MemoryMapLib/MemoryMapLib.c"
echo
echo "=== MemoryMapLib.c size + mtime ==="
ls -l "$PKG/Library/MemoryMapLib/MemoryMapLib.c"
echo
echo "=== git status (uefi tree) ==="
cd /root/k70/uefi && git status --porcelain 2>&1 | head -40
echo
echo "=== git diff MemoryMapLib (if git) ==="
cd /root/k70/uefi && git diff --stat 2>&1 | head -20
echo
echo "=== recently modified files in pkg (newer than keys149 build ~02:56) ==="
find "$PKG" -newermt '2026-10-22 02:50' -type f \( -name '*.c' -o -name '*.h' -o -name '*.inc' -o -name '*.dsc' -o -name '*.fdf' -o -name '*.toml' \) -printf '%TY-%Tm-%Td %TH:%TM %p\n' 2>/dev/null | sort | head -40
echo
echo "=== SiliciumPkg / Sec / Pei / PrePi recently modified ==="
find /root/k70/uefi/Silicon/Silicium /root/k70/uefi/Mu_Basecore/MdeModulePkg/Core/Pei /root/k70/uefi/Mu_Basecore/EmbeddedPkg/PrePi -newermt '2026-10-22 02:50' -type f 2>/dev/null | head -20
echo
echo "=== build scripts touching MemoryMapLib ==="
grep -rn 'MemoryMapLib' /mnt/d/本地项目-01/_tools/*.py /mnt/d/本地项目-01/_tools/*.sh /mnt/d/本地项目-01/_k70port_extract/wsl/*.sh 2>/dev/null | head -20
echo
echo "=== keys149/150 FD mtimes + sha ==="
ls -l /mnt/d/本地项目-01/_k70port_extract/qemu-fw/SILICIUM_UEFI-keys14*.fd /mnt/d/本地项目-01/_k70port_extract/qemu-fw/SILICIUM_UEFI-keys15*.fd 2>/dev/null
