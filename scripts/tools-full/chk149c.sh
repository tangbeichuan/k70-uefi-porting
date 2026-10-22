set +e
B=/mnt/d/本地项目-01/_k70port_extract/wsl/build_keys149.sh
echo "=== patch invocations in build_keys149.sh ==="
grep -n 'patch_\|\.py' "$B" | head -30
echo "=== scripts that copy VermeerMenuDxe source ==="
grep -l 'VermeerMenuDxe' /mnt/d/本地项目-01/_tools/*.py 2>/dev/null
echo "=== strings sample in built efi ==="
strings /root/k70/uefi/Build/vermeerPkg/DEBUG_CLANGPDB/AARCH64/VermeerMenuDxe.efi | head -20