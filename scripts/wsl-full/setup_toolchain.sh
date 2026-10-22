#!/usr/bin/env bash
# Install the host toolchain needed by Mu-Silicium / EDK2 (CLANGPDB, AARCH64).
set -o pipefail
export DEBIAN_FRONTEND=noninteractive
echo "===== apt-get update ====="
apt-get -o Acquire::Retries=3 update 2>&1 | tail -3
echo
echo "===== apt-get install ====="
apt-get -y --no-install-recommends install \
  build-essential uuid-dev nasm acpica-tools device-tree-compiler mtools \
  ninja-build python3-pip python3-venv python3-dev git curl ca-certificates \
  unzip xz-utils zstd libssl-dev pkg-config bc ccache dosfstools \
  clang lld llvm 2>&1 | tail -15
echo
echo "===== versions ====="
clang --version 2>&1 | head -2
ld.lld --version 2>&1 | head -1
make --version | head -1
gcc --version | head -1
python3 --version
nasm -v 2>&1 | head -1
iasl -v 2>&1 | head -2
dtc --version 2>&1
echo
echo "===== venv + pip ====="
python3 -m venv /root/k70/venv 2>&1 | tail -2
/root/k70/venv/bin/python -m pip install -q --upgrade pip 2>&1 | tail -2
/root/k70/venv/bin/python -m pip --version
