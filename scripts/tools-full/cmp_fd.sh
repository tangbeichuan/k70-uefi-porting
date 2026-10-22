set +e
cd /mnt/d/本地项目-01/_k70port_extract/qemu-fw
ls -l SILICIUM_UEFI-keys10*.fd 2>/dev/null | tail -5
sha256sum SILICIUM_UEFI-keys106.fd SILICIUM_UEFI-keys107.fd 2>/dev/null
echo "--- diff bytes ---"
cmp -l SILICIUM_UEFI-keys106.fd SILICIUM_UEFI-keys107.fd 2>/dev/null | wc -l
echo "--- images ---"
cd /mnt/d/本地项目-01/K70-UEFI-build
ls -l Mu-vermeer-keys10*.img 2>/dev/null | tail -6
sha256sum Mu-vermeer-keys106.img Mu-vermeer-keys107.img 2>/dev/null