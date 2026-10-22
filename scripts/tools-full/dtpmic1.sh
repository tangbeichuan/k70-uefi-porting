set +e
SRC=/mnt/d/本地项目-01/_k70_pkg_1019/K70-UEFI-package/extracted/xbl_config_fdt_10168.dtb
WORK=/mnt/d/_k70tmp/pmic
rm -rf $WORK; mkdir -p $WORK
dtc -I dtb -O dts -o $WORK/full.dts $SRC 2>/dev/null
echo "lines: $(wc -l < $WORK/full.dts)"
python3 - <<'PY'
import re
p='/mnt/d/_k70tmp/pmic/full.dts'
s=open(p).read()
i=s.find('/sw/pmic')
print("has /sw/pmic:", i>0)
# print the pmic subtree node names
seg=s[i:]
end=seg.find('\n\t};')
print(seg[:1200])
PY