set +e
cd /root/k70/uefi/Build/vermeerPkg/DEBUG_CLANGPDB/FV
ls -l SILICIUM_UEFI.fd 2>/dev/null
sha256sum SILICIUM_UEFI.fd 2>/dev/null
ls -l /mnt/d/本地项目-01/_k70port_extract/qemu-fw/SILICIUM_UEFI-keys6[5-9].fd
sha256sum /mnt/d/本地项目-01/_k70port_extract/qemu-fw/SILICIUM_UEFI-keys69.fd
echo "=== keys69 FD 里 HALIOMMU 的 GUID 在不在（解压后搜 GUID 字节）==="
python3 - <<'PY'
import lzma,io,struct
fd=open('/mnt/d/本地项目-01/_k70port_extract/qemu-fw/SILICIUM_UEFI-keys69.fd','rb').read()
g=bytes.fromhex('1f77009ad436d54d891 6c48ed9b16b86'.replace(' ',''))
print('raw GUID bytes in FD:', fd.find(g))
PY