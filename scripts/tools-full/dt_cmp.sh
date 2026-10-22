set +e
cd /mnt/d/_k70tmp
echo "=== cb20: ???? ==="
dtc -I dtb -O dts xbl_config_fdt_cb20.dtb 2>/dev/null | grep -nE '^\s{0,8}[a-zA-Z0-9_@,.-]+ \{' | head -40
echo
echo "=== cb20: ??? iort / pmic / pwr ==="
dtc -I dtb -O dts xbl_config_fdt_cb20.dtb 2>/dev/null | grep -cE 'iort'
dtc -I dtb -O dts xbl_config_fdt_cb20.dtb 2>/dev/null | grep -nE 'pmic|pwr' | head -20
echo
echo "=== 10168: ???? ==="
dtc -I dtb -O dts xbl_config_fdt_10168.dtb 2>/dev/null | grep -nE '^\s{0,8}[a-zA-Z0-9_@,.-]+ \{' | head -40
echo
echo "=== 10168: iort / pmic ==="
dtc -I dtb -O dts xbl_config_fdt_10168.dtb 2>/dev/null | grep -nE 'iort|pmic|pwr' | head -30