set +e
B=/root/k70/uefi/Build/vermeerPkg/DEBUG_CLANGPDB/FV/SILICIUM_UEFI.fd
Q=/mnt/d/本地项目-01/_k70port_extract/qemu-fw
sha256sum "$B" $Q/SILICIUM_UEFI-keys106.fd $Q/SILICIUM_UEFI-keys108.fd
echo "--- FV list files ---"
ls -l --time-style=+%H:%M:%S /root/k70/uefi/Build/vermeerPkg/DEBUG_CLANGPDB/FV/*.Fv 2>/dev/null | head
echo "--- does FVMAIN text list contain SimpleFb? ---"
grep -c "SimpleFb" /root/k70/uefi/Build/vermeerPkg/DEBUG_CLANGPDB/FV/FVMAIN.Fv.txt 2>/dev/null
grep -n "SimpleFb" /root/k70/uefi/Build/vermeerPkg/DEBUG_CLANGPDB/FV/FVMAIN.Fv.txt 2>/dev/null | head -3
ls /root/k70/uefi/Build/vermeerPkg/DEBUG_CLANGPDB/FV/ | head -20