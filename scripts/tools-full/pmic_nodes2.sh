set +e
U=/root/k70/uefi
F=$(find "$U/Binaries" -name 'PmicDxe*.efi' | head -3 | tail -1)
echo "PmicDxe candidate: $F"
find "$U/Binaries" -name 'PmicDxe*.efi'
B=$(find /mnt/d/????-01/_k70port_pkg_1019 -name 'xbl_config_fdt_cb20.dtb' | head -1)
echo "blob: $B"
echo "=== PmicDxe node paths ==="
strings -n 5 "$F" 2>/dev/null | grep -E '/soc/pmic|/pmic/' | sort -u | head -40
echo "=== cb20 /soc/pmic subtree (first levels) ==="
dtc -I dtb -O dts "$B" 2>/dev/null | grep -nE 'pmic|pwr|resin|kpd|vulo' | head -60