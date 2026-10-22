set +e
grep -i "2C9A63D4" /tmp/guid-keys100.xref && echo "APP IN FV: yes" || echo "APP IN FV: NO"
grep -i "8E47F1A2" /tmp/guid-keys100.xref >/dev/null && echo "stub: yes" || echo "stub: NO"
cd /mnt/d/本地项目-01/_k70port_extract/wsl
bash pack_keys.sh /mnt/d/本地项目-01/_k70port_extract/qemu-fw/SILICIUM_UEFI-keys100.fd keys100 2>&1 | tail -4