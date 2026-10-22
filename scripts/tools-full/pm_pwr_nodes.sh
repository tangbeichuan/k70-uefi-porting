set +e
cd /mnt/d/_k70tmp
for f in xbl_config_fdt_cb20.dtb xbl_config_fdt_10168.dtb; do
  echo "=== $f"
  dtc -I dtb -O dts $f 2>/dev/null | awk '/pm \{$/,/psi \{/' | grep -E '^\s+[a-zA-Z0-9_-]+ \{' | sed 's/[0-9a-fx&=<>;]//g' | sort -u
done