#!/bin/bash
# keys25 = keys24 (DTB extension HOB now correct) but the probe driver is dispatched at the END
# of APRIORI, so EnvDxe / UFSDxe have already run by the time it prints.
set -e
cd /mnt/d/本地项目-01/_k70port_extract/wsl

sed -e 's/^TAG=${1:-keys23}/TAG=${1:-keys25}/' \
    -e 's|"MdeModulePkg/Universal/PCD/Dxe/Pcd.inf" in line|"RscDxe/RscDxe.inf" in line|' \
    -e 's|# keys23 = keys22 + the real fix for the DTB extension HOB.|# keys25 = keys24 + probe dispatched at END of APRIORI.|' \
    build_keys23.sh > build_keys25.sh
chmod +x build_keys25.sh

echo "=== sanity: anchor + tag ==="
grep -n 'TAG=${1:-keys25}\|RscDxe/RscDxe.inf\|Pcd.inf' build_keys25.sh | head

echo "===== BUILD keys25 ====="
bash build_keys25.sh keys25 2>&1 | tail -25