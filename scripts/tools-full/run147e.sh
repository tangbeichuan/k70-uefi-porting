set -e
cd /mnt/d/本地项目-01/_k70port_extract/wsl
sed 's/keys147d/keys147e/g' build_keys147d.sh > build_keys147e.sh
sed 's/keys147d/keys147e/g' run_keys147d.sh > run_keys147e.sh
chmod +x build_keys147e.sh run_keys147e.sh
set +e
bash run_keys147e.sh 2>&1 | tail -12
echo "=== verify RUN + DIAG both present ==="
D=$(find /root/k70/uefi/Build/vermeerPkg/DEBUG_CLANGPDB -name 'VermeerDtbExtnDxe.efi' | head -1)
strings "$D" | grep -c 'VBUS' 
L=$(find /root/k70/uefi/Build/vermeerPkg/DEBUG_CLANGPDB -name 'VermeerLogDiskDxe.efi' | head -1)
strings "$L" | grep -c 'USBDIAG'
ls -l /mnt/d/本地项目-01/K70-UEFI-build/Mu-vermeer-keys147e.img
sha256sum /mnt/d/本地项目-01/K70-UEFI-build/Mu-vermeer-keys147e.img