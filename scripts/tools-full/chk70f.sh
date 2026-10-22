set +e
cd /root/k70/uefi
git checkout -- Platforms/Xiaomi/vermeerPkg/vermeer.dsc Platforms/Xiaomi/vermeerPkg/vermeer.fdf Platforms/Xiaomi/vermeerPkg/Include/DXE.inc Platforms/Xiaomi/vermeerPkg/Include/APRIORI.inc
echo "clean:"; grep -c 'keys47-drop\|keys70-hard' Platforms/Xiaomi/vermeerPkg/Include/APRIORI.inc
cd /mnt/d/本地项目-01/_k70port_extract/wsl
bash run_keys70.sh keys70 > /tmp/k70b.log 2>&1; echo "exit=$?"
grep -nE 'hard-dropped|kept vendor|dropped lines|UFSDxe kept|Success' /tmp/k70b.log | tail -6
for g in 9A00771F 0D35CD8E 5B21E7C4 90A49AFD 5C1E9A73; do printf "%s : " $g; grep -c "$g" /root/k70/uefi/Build/vermeerPkg/DEBUG_CLANGPDB/FV/FVMAIN.Fv.txt; done
grep -c '^0x' /root/k70/uefi/Build/vermeerPkg/DEBUG_CLANGPDB/FV/FVMAIN.Fv.txt
sha256sum /mnt/d/本地项目-01/_k70port_extract/qemu-fw/SILICIUM_UEFI-keys70.fd
cd /mnt/d/本地项目-01/_k70port_extract/wsl
bash pack_keys.sh "/mnt/d/本地项目-01/_k70port_extract/qemu-fw/SILICIUM_UEFI-keys70.fd" keys70 2>&1 | tail -4