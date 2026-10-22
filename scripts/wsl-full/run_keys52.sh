#!/bin/bash
# keys52 = keys51 的 provider 不动，只把 UFSDxe 换回原厂未打补丁的版本。
#
# 背景：树里 UFSDxe.inf 用的是 PE32|UFSDxe.patched.efi|*，那是 nuwa（同为 SM8550）作者打的
# 8 字节补丁（0x9574: bl 0xa8dc; cbnz w0 -> mov w1,#1; bl 0xaa0c）。它假定 nuwa 的 XBL 接口行为，
# 而我们现在的 DTBExtn 接口是自己实现的，那处补丁的假设可能根本不成立。
# 这个版本做一次干净 A/B：stock UFSDxe + 我们的 provider。
set -e -o pipefail

TAG=${1:-keys52}
UEFI=/root/k70/uefi
DIR=$UEFI/Binaries/vermeer/QcomPkg/Drivers/UFSDxe
TOOLS=/mnt/d/本地项目-01/_k70port_extract

cp "$DIR/UFSDxe.patched.efi" /tmp/UFSDxe.patched.efi.bak
restore() { cp /tmp/UFSDxe.patched.efi.bak "$DIR/UFSDxe.patched.efi"; }
trap restore EXIT

cp "$DIR/UFSDxe.efi" "$DIR/UFSDxe.patched.efi"
echo "UFSDxe.patched.efi <- stock UFSDxe.efi ($(stat -c%s "$DIR/UFSDxe.patched.efi") bytes)"
cmp -s "$DIR/UFSDxe.efi" "$DIR/UFSDxe.patched.efi" && echo "verified: identical to stock"

bash "$TOOLS/wsl/run_keys47.sh" "$TAG"
