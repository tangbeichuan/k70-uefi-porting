set +e
cd /mnt/d/_k70tmp
for f in xbl_config_fdt_cb20.dtb xbl_config_fdt_10168.dtb; do
  echo "=== $f  pre-psi ??: $(dtc -I dtb -O dts $f 2>/dev/null | grep -c 'pre-psi')"
  echo "=== $f  /sw/pmic/pm/pon ???:"
  dtc -I dtb -O dts $f 2>/dev/null | awk '/pon \{/{f=1} f{print} f&&/^\t\t\t\t\t\};/{exit}' | grep -E '\{' | head -15
done