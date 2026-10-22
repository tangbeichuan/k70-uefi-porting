set -e
cd /mnt/d/本地项目-01/_k70port_extract/wsl
sed 's/keys148/keys149/g' build_keys148.sh > build_keys149.sh
sed 's/keys148/keys149/g' run_keys148.sh > run_keys149.sh
chmod +x build_keys149.sh run_keys149.sh
set +e
bash run_keys149.sh 2>&1 | tail -10
D=$(find /root/k70/uefi/Build/vermeerPkg/DEBUG_CLANGPDB -name 'VermeerMenuDxe.efi' | head -1)
echo "menu efi: $D"
strings "$D" | grep -c 'USB149'
ls -l /mnt/d/本地项目-01/K70-UEFI-build/Mu-vermeer-keys149.img
sha256sum /mnt/d/本地项目-01/K70-UEFI-build/Mu-vermeer-keys149.img