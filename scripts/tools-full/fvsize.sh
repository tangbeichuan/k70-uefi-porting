set +e
cd /mnt/d/本地项目-01/_k70port_extract/qemu-fw
for t in keys70 keys83; do
  f=SILICIUM_UEFI-$t.fd
  [ -f "$f" ] && echo "$t FD: $(stat -c%s $f) bytes  sha=$(sha256sum $f | cut -c1-16)"
done
ls -l SILICIUM_UEFI-keys7*.fd SILICIUM_UEFI-keys8*.fd 2>/dev/null | tail -8