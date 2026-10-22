#!/usr/bin/env bash
# 谁提供 DTBExtnProtocol？在 vendor Binaries 里搜提供者，并看现有模块列表里有没有它。
set -u
cd /root/k70/uefi || exit 1
echo "=== Binaries 里含 'DTBExtn' 字符串的 .efi ==="
grep -ril 'DTBExtn' Binaries/vermeer --include=*.efi 2>/dev/null | sed 's|^|  |'
echo
echo "=== 对应 INF（同目录）==="
for f in $(grep -ril 'DTBExtn' Binaries/vermeer --include=*.efi 2>/dev/null); do
  d=$(dirname "$f"); echo "  $d"; ls "$d"/*.inf 2>/dev/null | sed 's|^|      |'
done
echo
echo "=== 这些 INF 是否没被 APRIORI/DSC 引用（=没编进固件）==="
for g in $(grep -ril 'DTBExtn' Binaries/vermeer --include=*.efi 2>/dev/null); do
  base=$(basename "$g" .efi)
  n=$(grep -rc "$base" Platforms/Xiaomi/vermeerPkg/vermeer.dsc Platforms/Xiaomi/vermeerPkg/vermeer.fdf Platforms/Xiaomi/vermeerPkg/Include/*.inc 2>/dev/null | awk -F: '{s+=$2} END{print s}')
  echo "  $base  refs=$n"
done
echo
echo "=== DxeDtPlatformDtbLoaderLibDefault 实现要点 ==="
sed -n '1,80p' Mu_Basecore/EmbeddedPkg/Library/DxeDtPlatformDtbLoaderLibDefault/DxeDtPlatformDtbLoaderLibDefault.c 2>/dev/null | grep -nE 'Pcd|Fv|Section|Guid|Locate|STATUS|return' | head -25
echo
echo "=== 该 lib 的 INF LibraryClasses/PCDs ==="
cat Mu_Basecore/EmbeddedPkg/Library/DxeDtPlatformDtbLoaderLibDefault/DxeDtPlatformDtbLoaderLibDefault.inf 2>/dev/null | sed -n '1,40p'
