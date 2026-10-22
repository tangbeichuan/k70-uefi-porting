set +e
F=/root/k70/uefi/Binaries/vermeer/QcomPkg/Drivers/PmicDxe/PmicDxe.efi
echo "=== PmicDxe ???? /soc/pmic? ?? ==="
strings -n 6 "$F" | grep -E '^/soc/pmic|^/pmic' | sort -u | head -60
echo
echo "=== ??? blob(cb20) ? /soc/pmic ????? ==="
dtc -I dtb -O dts /mnt/d/????-01/_k70port_pkg_1019/K70-UEFI-package/extracted/xbl_config_fdt_cb20.dtb 2>/dev/null | awk '/pmic \{/,0' | grep -E '^\s{0,12}[a-zA-Z0-9_@,.-]+ \{' | head -60