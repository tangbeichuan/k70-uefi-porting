set +e
grep -i "8E47F1A2" /tmp/guid-keys98.xref >/dev/null && echo "stub in FV: yes" || echo "stub in FV: NO"
cd /mnt/d/本地项目-01/_k70port_extract/wsl
bash pack_keys.sh /mnt/d/本地项目-01/_k70port_extract/qemu-fw/SILICIUM_UEFI-keys98.fd keys98 2>&1 | tail -5