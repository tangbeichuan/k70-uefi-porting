#!/usr/bin/env bash
# keys140 = keys139 lineage, but with patch_nopmic138.py removed so the real vendor
# PmicDxeLa.efi is back in the FV (this is the image that can actually exercise 0x1e3a8).
set +e
cd /mnt/d/本地项目-01/_k70port_extract/wsl || exit 1

# build: rename 139 -> 140 and drop the "comment out PmicDxeLa" patch step
sed -e 's/keys139/keys140/g' \
    -e 's# \&\& python3 /mnt/d/本地项目-01/_tools/patch_nopmic138.py##' \
    build_keys139.sh > build_keys140.sh

# runner: 139 -> 140
sed -e 's/keys139/keys140/g' run_keys139.sh > run_keys140.sh
chmod +x build_keys140.sh run_keys140.sh

echo "--- patch chain in build_keys140.sh ---"
grep -n "patch_" build_keys140.sh
echo "--- nopmic still present? (should be 0) ---"
grep -c "patch_nopmic138" build_keys140.sh
echo "--- running run_keys140.sh ---"
bash run_keys140.sh > /tmp/b140.log 2>&1
RC=$?
echo "runner rc=$RC"
tail -25 /tmp/b140.log
