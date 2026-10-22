#!/bin/bash
# keys43 = keys42（真版 PlatformPeiLib + EnvDxe 在位）
#          但把 Scheduler Interface HOB 和 DTB Extension HOB 双双关掉：
#          这两个 HOB 的载荷都是 0xA703A290（XblProtocols 解析出的 GUID 常量表地址），
#          EnvDxe 把它当 0x108 字节接口用，读 +0x58 就拿到 0x049D2B073D213397 -> 崩。
#          Info Blk / Shim / Prodmode 三个 HOB 保留。
set -u
cd /mnt/d/本地项目-01/_k70port_extract/wsl || exit 1
TAG=keys43

python3 /mnt/d/本地项目-01/_tools/patch_pei43.py || exit 1

python3 - <<'PY'
import pathlib
src = pathlib.Path('/mnt/d/本地项目-01/_k70port_extract/wsl/build_keys42.sh').read_text()
pathlib.Path('/mnt/d/本地项目-01/_k70port_extract/wsl/build_keys43.sh').write_text(src.replace('keys42', 'keys43'))
print('wrote build_keys43.sh')
PY

bash build_keys43.sh "$TAG" || exit 1
bash pack_keys.sh /mnt/d/本地项目-01/_k70port_extract/qemu-fw/SILICIUM_UEFI-$TAG.fd "$TAG" || exit 1
cp /tmp/PlatformPei.c.bak43 /root/k70/uefi/Silicon/Qualcomm/QcomPkg/Library/PlatformPeiLib/PlatformPei.c
echo "=== keys43 done ==="
