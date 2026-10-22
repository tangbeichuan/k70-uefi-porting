#!/usr/bin/env bash
# SM8550 家族的 DTB 里，谁能提供 UFSDxe 需要的固件侧属性？
set -u
D=/root/k70/uefi/Resources/DTBs
echo "=== SM8550 candidates present? ==="
for n in nuwa fuxi ishtar marble vermeer sheng corot diting mondrian yudi; do
  ls -l "$D/$n.dtb" 2>/dev/null
done
echo
echo "=== property hits (init_speed_params / ufs0_vcc / timeout_values) ==="
for f in "$D"/nuwa.dtb "$D"/fuxi.dtb "$D"/ishtar.dtb "$D"/marble.dtb "$D"/vermeer.dtb \
         /mnt/d/本地项目-01/_k70port_extract/k70-port/extracted/vermeer-live.dtb \
         /mnt/d/本地项目-01/_k70port_extract/port/Resources/DTBs/vermeer.dtb; do
  [ -f "$f" ] || continue
  a=$(strings -a "$f" | grep -c -i init_speed_params)
  b=$(strings -a "$f" | grep -c -i 'ufs0_vcc')
  c=$(strings -a "$f" | grep -c -i timeout_values)
  d=$(strings -a "$f" | grep -c -i 'ufs1_vcc')
  printf '%-58s init=%-3s ufs0_vcc=%-3s timeout=%-3s ufs1_vcc=%s\n' "$(basename "$f")" "$a" "$b" "$c" "$d"
done
echo
echo "=== who has the /soc/ufs0 node shape? (search all DTBs, stop at first 12 hits) ==="
cnt=0
for f in "$D"/*.dtb; do
  if strings -a "$f" | grep -qi init_speed_params; then
    echo "  HIT $(basename "$f")"
    cnt=$((cnt+1)); [ "$cnt" -ge 12 ] && break
  fi
done
echo
echo "=== UFSDxe property lookups (strings around) ==="
strings -a "$D/../../Binaries/vermeer/QcomPkg/Drivers/UFSDxe/UFSDxe.efi" 2>/dev/null \
  | grep -E 'ufs|UFS|/soc/|/pmic/' | sort -u | head -40
