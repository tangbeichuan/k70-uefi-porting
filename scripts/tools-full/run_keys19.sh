#!/usr/bin/env bash
bash /mnt/d/本地项目-01/_k70port_extract/wsl/build_keys18.sh keys19 > /tmp/keys19.log 2>&1
echo "EXIT=$?"
grep -iE 'error|failed|assert' /tmp/keys19.log | head -20
tail -30 /tmp/keys19.log
