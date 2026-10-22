#!/usr/bin/env bash
set +e
cd /root/k70/uefi
echo "===== ext_dep dirs ====="
find . -maxdepth 3 -name 'ext_dep' -o -maxdepth 3 -name '*.json' -path '*dependenc*' 2>/dev/null | head
cat Platforms/Xiaomi/vermeerPkg/DeviceBuild.py | sed -n '1,80p'
echo
echo "===== where did the 2 deps go? ====="
ls -la /root/k70/uefi/Build 2>/dev/null
find / -maxdepth 4 -type d -name 'Basetools' 2>/dev/null | head
find /root/k70 -maxdepth 4 -type d \( -name 'basetools*' -o -name 'onecrypto*' -o -name 'nasm*' \) 2>/dev/null | head
echo
echo "===== UPDATE_LOG tail ====="
tail -20 Build/UPDATE_LOG.txt 2>/dev/null
