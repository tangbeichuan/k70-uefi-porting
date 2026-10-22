#!/bin/bash
cd /tmp
echo "########## 10168: /soc/ufs0 node (first 90 lines from match) ##########"
sed -n '40,150p' xbl_config_fdt_10168.dtb.dts
echo
echo "########## 10168: aliases block ##########"
awk '/aliases \{/,/^\t\};/' xbl_config_fdt_10168.dtb.dts | head -40
echo
echo "########## 10168: /soc children (depth1 names) ##########"
awk '/^\tsoc \{/,0' xbl_config_fdt_10168.dtb.dts | grep -E '^\t\t[A-Za-z0-9_,@.-]+ \{' | sed 's/ {//' | sort -u | head -60
echo
echo "########## counts ##########"
for f in xbl_config_fdt_10168.dtb.dts xbl_config_fdt_cb20.dtb.dts; do
  printf "%-32s lines=%s nodes=%s ufs0=%s ufshc=%s pmic_client=%s\n" "$f" "$(wc -l < $f)" "$(grep -cE '^\t*[A-Za-z0-9_,@.-]+ \{' $f)" "$(grep -c 'ufs0@1D80000' $f)" "$(grep -c 'ufshc' $f)" "$(grep -c 'pmic/client' $f)"
done
