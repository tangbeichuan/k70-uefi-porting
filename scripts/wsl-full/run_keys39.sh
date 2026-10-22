#!/bin/bash
# keys39 = keys38 + 可读的自证式 UI 探针：每 2 秒打一行 tick / ConIn 状态，按键打 KEY 行，
#          全部使用固定字符串（不依赖 DEBUG 的 %s/%d），并周期复查 ConIn 是否就绪。
set -u
cd /mnt/d/本地项目-01/_k70port_extract/wsl || exit 1
TAG=keys39

python3 /mnt/d/本地项目-01/_tools/patch_driver39.py || exit 1

bash build_keys38.sh "$TAG" || exit 1
bash pack_keys.sh /mnt/d/本地项目-01/_k70port_extract/qemu-fw/SILICIUM_UEFI-$TAG.fd "$TAG" || exit 1
echo "=== keys39 done ==="
