#!/bin/bash
# keys40 = keys39 但把入口里那个阻塞的 InteractiveDemo() 从"实际执行路径"里移除
#          (keys38/39 就是卡在这里, 所以只出现一行乱码, 没有 tick)。
#          真正的交互由 2 秒周期定时器 UiNotify 完成。
set -u
cd /mnt/d/本地项目-01/_k70port_extract/wsl || exit 1
TAG=keys40

python3 /mnt/d/本地项目-01/_tools/patch_driver40.py || exit 1

bash build_keys38.sh "$TAG" || exit 1
bash pack_keys.sh /mnt/d/本地项目-01/_k70port_extract/qemu-fw/SILICIUM_UEFI-$TAG.fd "$TAG" || exit 1
echo "=== keys40 done ==="
