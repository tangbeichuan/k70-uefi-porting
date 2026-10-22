set +e
grep -i "8E47F1A2" /tmp/guid-keys97.xref || echo STUB-MISSING
cd /mnt/d/本地项目-01/_k70port_extract/wsl
bash pack_keys.sh /mnt/d/本地项目-01/_k70port_extract/qemu-fw/SILICIUM_UEFI-keys97.fd keys97 2>&1 | tail -6