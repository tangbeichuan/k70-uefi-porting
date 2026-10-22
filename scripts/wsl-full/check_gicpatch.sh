#!/usr/bin/env bash
set +e
echo "===== patches build_uefi.py applies ====="
grep -n 'MuPatches\|\.patch' /root/k70/uefi/build_uefi.py | head -20
echo
echo "===== available patches ====="
ls -1 /root/k70/uefi/Resources/MuPatches/
echo
echo "===== can Gic-Spurious apply to Mu_Basecore? ====="
cd /root/k70/uefi/Mu_Basecore || exit 1
git apply --check -v ../Resources/MuPatches/Gic-Spurious.patch 2>&1 | tail -8
echo
echo "===== what does it change? ====="
head -40 ../Resources/MuPatches/Gic-Spurious.patch
