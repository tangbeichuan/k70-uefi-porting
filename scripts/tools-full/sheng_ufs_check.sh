#!/usr/bin/env bash
# 关键问题：同 SoC 的 uefi-sheng 是怎么处理 UFS 的？它的 DT 里有固件侧 UFS 属性吗？
set -u
U=/mnt/d/本地项目-01/_k70port_extract/_upstream
S=$U/UniXNU__uefi-sheng

echo "=== uefi-sheng 顶层 ==="
ls "$S" 2>/dev/null
echo
echo "=== uefi-sheng 的 DTB ==="
ls -l "$S"/Resources/DTBs/ 2>/dev/null
for f in "$S"/Resources/DTBs/*.dtb; do
  [ -f "$f" ] || continue
  printf '%-24s init=%s ufs0_vcc=%s timeout=%s ufs0node=%s\n' \
    "$(basename "$f")" \
    "$(strings -a "$f" | grep -ci init_speed_params)" \
    "$(strings -a "$f" | grep -ci ufs0_vcc)" \
    "$(strings -a "$f" | grep -ci timeout_values)" \
    "$(strings -a "$f" | grep -ci 'soc/ufs0')"
done
echo
echo "=== sheng 的 DSC/FDF 里跟 ufs 有关的行 ==="
grep -rn -i 'ufs' "$S"/Platforms/Xiaomi/shengPkg/*.fdf "$S"/Platforms/Xiaomi/shengPkg/*.dsc 2>/dev/null | head -20
echo
echo "=== sheng 的 FDF 里 bin 引入清单（前 40 行 INF Binaries） ==="
grep -rn 'INF Binaries' "$S"/Platforms/Xiaomi/shengPkg/*.fdf 2>/dev/null | head -40
echo
echo "=== UniXNU-sheng 的 board.toml 里 storage/ufs 相关 ==="
grep -rn -i 'ufs\|storage\|block' "$U"/UniXNU__UniXNU-sheng/board.toml 2>/dev/null | head -20
