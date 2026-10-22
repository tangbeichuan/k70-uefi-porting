#!/bin/bash
# keys38 = 显式把 PlatformPeiLib 钉成 NULL 实现（SiliciumNullPkg），因此固件里根本不存在
#          DTB Extension HOB；探针回到 APRIORI 第 2 位，交互 UI 用 5 秒定时器延后触发。
set -u
cd /mnt/d/本地项目-01/_k70port_extract/wsl || exit 1
TAG=keys38

python3 /mnt/d/本地项目-01/_tools/patch_driver38.py || exit 1
python3 /mnt/d/本地项目-01/_tools/make_build38.py || exit 1

bash build_keys38.sh "$TAG" || exit 1
bash pack_keys.sh /mnt/d/本地项目-01/_k70port_extract/qemu-fw/SILICIUM_UEFI-$TAG.fd "$TAG" || exit 1
echo "=== keys38 done ==="
