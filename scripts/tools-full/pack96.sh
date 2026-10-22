set +e
grep -i "8E47F1A2" /tmp/guid-keys96.xref || echo "  STUB NOT IN FV"
grep -i "SmmuStub" /tmp/guid-keys96.xref || true
cd /mnt/d/本地项目-01/_k70port_extract/wsl
bash pack_keys.sh /mnt/d/本地项目-01/_k70port_extract/qemu-fw/SILICIUM_UEFI-keys96.fd keys96 2>&1 | tail -8