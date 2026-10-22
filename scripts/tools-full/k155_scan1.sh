#!/usr/bin/env bash
D=/root/k70/uefi/Silicon/Samsung/SamsungPkg/Include/Device/Dwc3.h
echo "=== Dwc3.h presence ==="
ls -l "$D" 2>/dev/null || echo missing
echo "=== GCTL/DCTL/PHYCFG/DSTS bit defs ==="
grep -nE 'GCTL_|DCTL_|GUSB2PHYCFG|DSTS_|PRTCAP' "$D" 2>/dev/null | head -80
echo
echo "=== search source tree for GCC register names ==="
cd /root/k70/uefi || exit 1
grep -rInE 'USB30_PRIM_GDSCR|USB3_PHY_GDSCR|USB30_PRIM_BCR|USB30_PRIM_CBCR|QUSB2PHY_PRIM_BCR' --include=*.h --include=*.c --include=*.dts --include=*.dtsi --include=*.inc . 2>/dev/null | head -30
echo
echo "=== _refs patches grep (windows dir via /mnt/d) ==="
grep -rInE 'USB3_PHY_GDSCR|USB30_PRIM_BCR|USB30_PRIM_CBCR|0x0f004|0x0F004' /mnt/d/本地项目-01/_refs/ios-vermeer-lab/xnu/patches 2>/dev/null | head -30
echo
echo "=== dts gcc/usb clock nodes ==="
grep -nE 'gcc|clock-controller|usb|gdscr|bcr' /mnt/d/本地项目-01/_tools/k148_xbl_ufs.dts 2>/dev/null | head -40
