#!/usr/bin/env bash
# stuart_update: pull the external dependencies (mu_nasm, Mu-Basetools, onecrypto-bin).
set +e
cd /root/k70/uefi || exit 1
. /root/k70/venv/bin/activate
LOG=/root/k70/update.log
stuart_update -c Platforms/Xiaomi/vermeerPkg/DeviceBuild.py 2>&1 | tee "$LOG" | tail -40
echo "===== exit: ${PIPESTATUS[0]} ====="
echo "===== external deps now present? ====="
for d in Build/Basetools Build/nasm Build/onecrypto; do [ -d "$d" ] && echo "  $d OK" || echo "  $d missing"; done
ls -d /root/k70/uefi/Build 2>/dev/null && ls /root/k70/uefi/Build | head -20
