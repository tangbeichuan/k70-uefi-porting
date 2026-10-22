set +e
grep -i "8E47F1A2" /tmp/guid-keys99.xref >/dev/null && echo "stub: yes" || echo "stub: NO"
cd /mnt/d/本地项目-01/_k70port_extract/wsl
bash pack_keys.sh /mnt/d/本地项目-01/_k70port_extract/qemu-fw/SILICIUM_UEFI-keys99.fd keys99 2>&1 | tail -4