#!/bin/bash
# keys44 = keys14 的构建原样（28 个 vendor 模块、PlatformPeiLib 保持默认 NULL、无任何 PEI 补丁）
#          + VermeerKeyProbeDxe 里新加的「音量键菜单」。
# keys14 是唯一在真机上做到「ConIn=yes 且音量键出 KEY 事件」的版本，所以直接回到它上面加 UI。
set -u
cd /mnt/d/本地项目-01/_k70port_extract/wsl || exit 1
TAG=keys44

bash build_keys14.sh "$TAG" || exit 1
bash pack_keys.sh /mnt/d/本地项目-01/_k70port_extract/qemu-fw/SILICIUM_UEFI-$TAG.fd "$TAG" || exit 1
echo "=== keys44 done ==="
