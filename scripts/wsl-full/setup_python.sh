#!/usr/bin/env bash
# Python build dependencies (stuart / edk2-pytool) + the AARCH64 cross binutils that
# Mu's CLANGPDB toolchain definition expects (CLANGPDB_AARCH64_PREFIX).
set -o pipefail
export DEBIAN_FRONTEND=noninteractive
echo "===== apt: aarch64 cross toolchain ====="
apt-get -y --no-install-recommends install gcc-aarch64-linux-gnu binutils-aarch64-linux-gnu 2>&1 | tail -6
echo
echo "===== pip install -r pip-requirements.txt (venv) ====="
cd /root/k70/uefi || exit 1
/root/k70/venv/bin/python -m pip install -q -r pip-requirements.txt 2>&1 | tail -20
echo "pip exit: $?"
echo
echo "===== installed ====="
/root/k70/venv/bin/python -m pip list 2>/dev/null | grep -iE 'edk2|antlr|regex|pefile|coloredlogs|pyyaml|toml' 
echo
echo "===== stuart present? ====="
ls /root/k70/venv/bin | grep -iE 'stuart|build' | head -10
