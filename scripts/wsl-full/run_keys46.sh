#!/bin/bash
# keys46 = keys44 的构建原样（keys14 基线 + 探针菜单），把菜单接上动作并加 3 秒倒计时：
#   1 Boot Linux (UFS)   占位
#   2 Boot UniXNU        占位
#   3 Device information 打印内存/handle/按键信息页
#   4 Reboot             gRT->ResetSystem (EfiResetCold)
#   5 Power off          gRT->ResetSystem (EfiResetShutdown)
# 没有 Enter 键，所以用「选中后 3 秒不动就执行」的倒计时（和 UniXNU 菜单一样的交互）。
set -u
cd /mnt/d/本地项目-01/_k70port_extract/wsl || exit 1
TAG=keys46
bash build_keys14.sh "$TAG" || exit 1
bash pack_keys.sh /mnt/d/本地项目-01/_k70port_extract/qemu-fw/SILICIUM_UEFI-$TAG.fd "$TAG" || exit 1
echo "=== keys46 done ==="
