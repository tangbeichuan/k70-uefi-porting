set +e
cd /mnt/d/_k70tmp
echo "=== cb20 /sw/pmic/pm/pwr ??? ==="
dtc -I dtb -O dts xbl_config_fdt_cb20.dtb 2>/dev/null | awk '/pwr \{/{f=1} f{print} f&&/^\t\t\t\t\};/{exit}' | grep -E '\{' | head -20
echo "=== 10168 /sw/pmic/pm/pwr ??? ==="
dtc -I dtb -O dts xbl_config_fdt_10168.dtb 2>/dev/null | awk '/pwr \{/{f=1} f{print} f&&/^\t\t\t\t\};/{exit}' | grep -E '\{' | head -20
echo "=== ???? pm-resin / pm_resin ==="
dtc -I dtb -O dts xbl_config_fdt_cb20.dtb 2>/dev/null | grep -c 'pm-resin'
dtc -I dtb -O dts xbl_config_fdt_10168.dtb 2>/dev/null | grep -c 'pm-resin'