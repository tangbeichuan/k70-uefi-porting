#!/bin/bash
T=/mnt/d/本地项目-01/_tools
echo "===== b152.log errors ====="
grep -n -i "error\|warning: \|fatal" $T/b152.log | head -40
echo "===== BUILDLOG tail 120 ====="
tail -160 /root/k70/uefi/Build/BUILDLOG_vermeerPkg.txt 2>/dev/null | grep -v "^$" | tail -100
