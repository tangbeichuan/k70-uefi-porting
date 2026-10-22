#!/usr/bin/env bash
bash /mnt/d/本地项目-01/_k70port_extract/wsl/build_keys18.sh keys20 > /tmp/keys20.log 2>&1
echo "BUILD EXIT=$?"
grep -iE ' error|error:|failed' /tmp/keys20.log | head -10
tail -12 /tmp/keys20.log
echo "=== pack ==="
bash /mnt/d/本地项目-01/_k70port_extract/wsl/pack_keys.sh /mnt/d/本地项目-01/_k70port_extract/qemu-fw/SILICIUM_UEFI-keys20.fd keys20 2>&1 | tail -5
ls -l /mnt/d/本地项目-01/K70-UEFI-build/Mu-vermeer-keys20*
