set +e
cd /mnt/d/本地项目-01/_k70port_extract/wsl
ls -1 build_keys147d.sh run_keys147d.sh 2>/dev/null
echo "=== pmic-re build script patch hooks ==="
grep -n 'patch_' build_keys147d.sh | head -10
echo "=== provider source has RUN block? ==="
grep -c 'VBUS\] run' /mnt/d/本地项目-01/_k70port_extract/port-drivers/VermeerDtbExtnDxe/VermeerDtbExtnDxe.c
echo "=== logdisk _tools copy has USBDIAG? ==="
grep -c 'USBDIAG' /mnt/d/本地项目-01/_tools/VermeerLogDiskDxe.c