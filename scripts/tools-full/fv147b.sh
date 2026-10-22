set +e
B=/root/k70/uefi/Build/vermeerPkg/DEBUG_CLANGPDB/FV
ls -l "$B"/FVMAIN.Fv "$B"/FVMAIN_COMPACT.Fv 2>/dev/null
echo "=== FD sizes ==="
ls -l /mnt/d/本地项目-01/_k70port_extract/qemu-fw/SILICIUM_UEFI-keys14{6,7b}.fd 2>/dev/null
echo "=== images ==="
ls -l /mnt/d/本地项目-01/K70-UEFI-build/Mu-vermeer-keys14{6,7b}.img 2>/dev/null
echo "=== keys147b FVMAIN.inf tail (order sanity) ==="
tail -5 "$B"/FVMAIN.inf 2>/dev/null