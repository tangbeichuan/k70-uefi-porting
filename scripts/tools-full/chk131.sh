set +e
P=/root/k70/uefi/Platforms/Xiaomi/vermeerPkg/Drivers/VermeerDtbExtnDxe/VermeerDtbExtnDxe.c
grep -n 'slot 0x40' "$P" | head -3
echo "--- built efi ---"
ls -l /root/k70/uefi/Build/vermeerPkg/DEBUG_CLANGPDB/AARCH64/vermeerPkg/Drivers/VermeerDtbExtnDxe/VermeerDtbExtnDxe/DEBUG/VermeerDtbExtnDxe.efi 2>/dev/null | cat
echo "--- fd ---"
ls -l /mnt/d/本地项目-01/K70-UEFI-build/Mu-vermeer-keys131.img /mnt/d/本地项目-01/K70-UEFI-build/Mu-vermeer-keys130.img | cat