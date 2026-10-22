#!/usr/bin/env bash
# 全盘找 init_speed_params / ufs0_vcc 的真实来源（固件侧 DTB 或 dts），
# 以及 K70 上可能存在的固件 DT 副本。
set -u
echo "=== grep binaries/sources for the property names ==="
for pat in init_speed_params ufs0_vcc timeout_values; do
  echo "-- $pat"
  grep -rla --binary-files=text "$pat" \
      /mnt/d/本地项目-01/_k70port_extract \
      /mnt/d/本地项目-01/K70-UEFI-build \
      2>/dev/null | head -15
done
echo
echo "=== any ufs dts anywhere under the extracted tree? ==="
grep -rla --binary-files=text -i 'ufshc\|/soc/ufs' /mnt/d/本地项目-01/_k70port_extract 2>/dev/null | head -20
echo
echo "=== what partitions does the phone expose (needs adb/bootloader)? ==="
WIN=/mnt/c/Users/QWQ/AppData/Local/Android/Sdk/platform-tools
"$WIN/adb.exe" devices 2>/dev/null
"$WIN/fastboot.exe" devices 2>/dev/null
