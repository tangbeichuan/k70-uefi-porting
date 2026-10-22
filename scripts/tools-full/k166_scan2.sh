#!/usr/bin/env bash
# k166_scan2.sh -- MemoryMapLib SMMU row + vendor SEC SMMU detach usage
set -e
MM=/root/k70/uefi/Platforms/Xiaomi/vermeerPkg/Library/MemoryMapLib/MemoryMapLib.c
echo "===== MemoryMapLib region rows ====="
grep -nE '\{ *"' "$MM" || true
echo
echo "===== SMMU mentions in MemoryMapLib ====="
grep -n -i "smmu" "$MM" || true
echo
echo "===== Kailua PlatformSec.c detach call ====="
grep -n -B10 -A25 'ArmSmmuDetach' /root/k70/uefi/Silicon/Qualcomm/KailuaPkg/Library/PlatformSecLib/PlatformSec.c || true
echo
echo "===== vermeer pkg: Smmu / PlatformSec references ====="
grep -rn -i "smmu" /root/k70/uefi/Platforms/Xiaomi/vermeerPkg --include=*.dsc --include=*.inc --include=*.fdf --include=*.c --include=*.h 2>/dev/null | head -20 || true
echo
echo "===== which PlatformSecLib does vermeer use? ====="
grep -rn "PlatformSecLib" /root/k70/uefi/Platforms/Xiaomi/vermeerPkg 2>/dev/null | head -20 || true
grep -rn "PlatformSecLib\|ArmSmmuDetachLib" /root/k70/uefi/Silicon/Qualcomm/KailuaPkg/*.dsc /root/k70/uefi/Silicon/Qualcomm/KailuaPkg/*.dsc.inc 2>/dev/null | head -20 || true
