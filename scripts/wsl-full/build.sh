#!/usr/bin/env bash
# Install the vermeer overlay into the uefi-sheng checkout and build the FD.
set -e
UE=/root/k70/uefi
PORT=/mnt/d/本地项目-01/_k70port_extract/port
LOG=/root/k70/build-vermeer.log

echo "===== installing overlay ====="
cp -a "$PORT"/. "$UE"/
ls -d "$UE/Platforms/Xiaomi/vermeerPkg" "$UE/Binaries/vermeer" "$UE/Resources/DTBs/vermeer.dtb" \
      "$UE/Resources/Configs/vermeer.toml"
echo "vendor binaries: $(find "$UE/Binaries/vermeer" -name '*.efi' | wc -l) .efi"

cd "$UE"
. /root/k70/venv/bin/activate
echo "python: $(python3 --version)  clang: $(clang --version | head -1)"

echo "===== build (DEBUG) ====="
set +e
python3 build_uefi.py -d vermeer -m 0 -r DEBUG 2>&1 | tee "$LOG"
rc=${PIPESTATUS[0]}
echo "===== build exit: $rc ====="
echo "log: $LOG"
ls -l Build/vermeerPkg/*/FV/ 2>/dev/null
exit $rc
