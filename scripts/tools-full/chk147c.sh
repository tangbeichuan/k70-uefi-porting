set +e
D=$(find /root/k70/uefi/Build/vermeerPkg/DEBUG_CLANGPDB -name 'VermeerDtbExtnDxe.efi' | head -1)
echo "efi: $D"
grep -c 'VBUS' "$D" 2>/dev/null || strings "$D" | grep -c VBUS
strings "$D" | grep 'VBUS' | head -3
ls -l /mnt/d/本地项目-01/K70-UEFI-build/Mu-vermeer-keys147c.img