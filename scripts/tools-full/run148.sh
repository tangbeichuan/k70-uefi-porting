#!/bin/bash
# keys148 lineage: keys147d baseline (keys146 build script with 147d tag) + the
# keys148 DWC3 register-map fix (correct DCTL/DSTS offsets, GSNPSID/GUSB2PHYCFG
# dumps, late RUN_STOP) which lives in the provider/LogDisk sources, not in a
# binary patch.  No new FV module is added.
set -e
cd /mnt/d/本地项目-01/_k70port_extract/wsl
sed 's/keys146/keys148/g' build_keys146.sh > build_keys148.sh
sed 's/keys146/keys148/g' run_keys146.sh > run_keys148.sh
chmod +x build_keys148.sh run_keys148.sh
echo "=== patch chain in build_keys148.sh ==="
grep -n 'patch_' build_keys148.sh
echo "=== provider source sanity ==="
grep -c 'GSNPSID' /mnt/d/本地项目-01/_k70port_extract/port-drivers/VermeerDtbExtnDxe/VermeerDtbExtnDxe.c
grep -c 'UsbDiagEnsureRun' /mnt/d/本地项目-01/_tools/VermeerLogDiskDxe.c
set +e
bash run_keys148.sh 2>&1 | tail -25
echo "rc=$?"
echo "=== artifacts ==="
sha256sum /mnt/d/本地项目-01/_k70port_extract/qemu-fw/SILICIUM_UEFI-keys148.fd \
          /mnt/d/本地项目-01/K70-UEFI-build/Mu-vermeer-keys148.img 2>&1
