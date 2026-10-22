#!/usr/bin/env bash
# 1) 列出所有可用的 DTB；2) 逐个检查 UFSDxe 需要的固件侧属性是否在内。
set -u
UEFI=/root/k70/uefi
echo "=== DTB inventory ==="
ls -l "$UEFI/Resources/DTBs/" 2>/dev/null
find "$UEFI" -maxdepth 4 -name '*.dtb' -printf '%p  %s B\n' 2>/dev/null | head -40
echo
echo "=== extracted / port copies on the Windows side ==="
ls -l /mnt/d/本地项目-01/_k70port_extract/k70-port/extracted/*.dtb /mnt/d/本地项目-01/_k70port_extract/port/Resources/DTBs/*.dtb 2>/dev/null
echo

check() {
  local f="$1"
  [ -f "$f" ] || return
  echo "---- $f"
  for p in init_speed_params perf_speed_params timeout_values ufs0_vcc ufs0_vccq ufs_vcc ufs0 ufshc; do
    n=$(strings -a "$f" 2>/dev/null | grep -c -i -- "$p")
    [ "$n" -gt 0 ] && printf '     %-22s %s\n' "$p" "$n"
  done
  # 直接看节点名
  if command -v dtc >/dev/null 2>&1; then
    echo "     [dtc nodes]"
    dtc -I dtb -O dts "$f" 2>/dev/null | grep -n -i -E 'ufs|ufshc' | head -12 | sed 's/^/       /'
  fi
}

for f in "$UEFI"/Resources/DTBs/*.dtb /mnt/d/本地项目-01/_k70port_extract/k70-port/extracted/vermeer-live.dtb /mnt/d/本地项目-01/_k70port_extract/port/Resources/DTBs/vermeer.dtb; do
  check "$f"
done
