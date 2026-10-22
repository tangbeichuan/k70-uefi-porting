#!/bin/bash
P=/root/k70/uefi/Silicon/Qualcomm/QcomPkg/Library/PlatformPeiLib/PlatformPei.c
echo "=== PlatformPei.c around PlatformPeim / BuildXblHobs ==="
grep -n "BuildXblHobs\|DtbExtension\|SchedulerInterface\|BuildGuidDataHob\|InstallPpi\|MemoryAllocation" "$P" | head -40
echo
echo "=== lines 90-170 ==="
sed -n '90,170p' "$P"
