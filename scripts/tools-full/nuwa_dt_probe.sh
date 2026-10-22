#!/usr/bin/env bash
# 看上游 nuwaPkg 怎么处理设备树（有没有 DtPlatformDxe / FdtBlob / 真 DT），
# 以及上游 DT 里有没有 UFSDxe 需要的 /soc/ufs0 节点。nuwa 与 vermeer 同为 SM8550。
set -u
cd /mnt/d/本地项目-01/_k70port_extract/_upstream/Project-Silicium__Mu-Silicium/Platforms/Xiaomi/nuwaPkg || exit 1
echo "=== 目录 ==="
ls
echo
echo "=== fdf/dsc/inc 里与 DT 相关的行 ==="
grep -rn 'DtPlatform\|FdtBlob\|FILE FREEFORM\|25462CDA' *.fdf *.dsc Include/*.inc 2>/dev/null | head -20
echo
echo "=== 任何 dtb/dtsi ==="
find . -name '*.dtb' -o -name '*.dtsi' -o -name '*.dts' | head -20
echo
echo "=== 若有 dtb，检查 ufs 相关节点 ==="
for f in $(find . -name '*.dtb'); do
  printf '%s  size=%s  init_speed_params=%s  ufs0=%s  ufshc=%s\n' "$f" "$(stat -c %s "$f")" \
    "$(grep -c -a init_speed_params "$f")" "$(grep -c -a ufs0 "$f")" "$(grep -c -a ufshc "$f")"
done
echo
echo "=== 上游 SiliciumPkg / 公共库里的 Dtb 相关驱动 ==="
cd /mnt/d/本地项目-01/_k70port_extract/_upstream/Project-Silicium__Mu-Silicium || exit 1
ls
