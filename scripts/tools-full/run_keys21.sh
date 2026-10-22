#!/usr/bin/env bash
bash /mnt/d/本地项目-01/_k70port_extract/wsl/build_keys18.sh keys21 > /tmp/keys21.log 2>&1
echo "BUILD EXIT=$?"
grep -iE ' error|error:|failed' /tmp/keys21.log | head -10
tail -8 /tmp/keys21.log
echo "=== pack ==="
bash /mnt/d/本地项目-01/_k70port_extract/wsl/pack_keys.sh /mnt/d/本地项目-01/_k70port_extract/qemu-fw/SILICIUM_UEFI-keys21.fd keys21 2>&1 | tail -5
ls -l /mnt/d/本地项目-01/K70-UEFI-build/Mu-vermeer-keys21* 2>/dev/null
