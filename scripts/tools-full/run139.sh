#!/usr/bin/env bash
# keys139 lineage runner: keys138 + port-drivers VermeerDtbExtnDxe (P0/P1 box-ABI fix).
set +e
cd /mnt/d/本地项目-01/_k70port_extract/wsl || exit 1

sed -e 's/keys138/keys139/g' build_keys138.sh > build_keys139.sh
sed -e 's/keys138/keys139/g' run_keys138.sh   > run_keys139.sh
chmod +x build_keys139.sh run_keys139.sh

echo "--- build_keys139.sh patch chain ---"
grep -n "patch_" build_keys139.sh
echo "--- running run_keys139.sh ---"
bash run_keys139.sh > /tmp/b139.log 2>&1
RC=$?
echo "runner rc=$RC"
tail -30 /tmp/b139.log
