#!/usr/bin/env bash
# Look at the build entry points that a board port has to satisfy.
set -o pipefail
cd /root/k70/uefi || exit 1
echo "===== build_uefi.py (first 90 lines) ====="
head -90 build_uefi.py
echo
echo "===== build_uefi.py: device list / dsc discovery ====="
grep -nE "devices|Platforms|dsc|argparse|add_argument|def main|def build" build_uefi.py | head -40
echo
echo "===== build_active_devices.sh ====="
cat build_active_devices.sh
echo
echo "===== Resources/Configs listing ====="
ls -1 Resources/Configs 2>/dev/null
echo
echo "===== Resources/Configs/sheng.toml ====="
cat Resources/Configs/sheng.toml 2>/dev/null
