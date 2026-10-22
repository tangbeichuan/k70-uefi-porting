#!/usr/bin/env bash
# UFS next-step facts: which DT does the firmware actually see, and does it carry the
# nodes UFSDxe asks for (/soc/ufs%d/init_speed_params, /pmic/client/ufs0_vcc, ...)?
PKG=/root/k70/uefi/Platforms/Xiaomi/vermeerPkg
echo "=== DTBs in the platform package ==="
ls -l "$PKG/FdtBlob/" 2>/dev/null
ls -l "$PKG/../../../../Resources/DTBs/" 2>/dev/null
echo
probe() {
  local f="$1"
  [ -f "$f" ] || { echo "  (missing $f)"; return; }
  echo "== $f  ($(stat -c %s "$f") B)"
  for p in ufs0 ufshc@1d84000 init_speed_params perf_speed_params timeout_values ufs0_vcc ufsphy_mem; do
    n=$(strings -a "$f" | grep -c -i -- "$p" || true)
    printf '   %-24s %s\n' "$p" "${n:-0}"
  done
}
probe "$PKG/FdtBlob/sm8550-xiaomi-vermeer.dtb"
probe /root/k70/uefi/Resources/DTBs/vermeer.dtb
echo
echo "=== does anything in the platform reference the FdtBlob? ==="
grep -rn 'FdtBlob\|vermeer.dtb' "$PKG/vermeer.dsc" "$PKG/vermeer.fdf" "$PKG/Include/"*.inc 2>/dev/null | head
echo
echo "=== how does the port load the DT at runtime? (grep for DtbLib/DtPlatform) ==="
grep -rln 'DtPlatform\|DtbLoader\|Fdt' "$PKG" --include=*.c --include=*.inf 2>/dev/null | head -10
