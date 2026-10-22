#!/bin/bash
# keys42 = 真版 PlatformPeiLib（恢复 Info Blk / Shim / Prodmode / Scheduler 这四个 HOB，EnvDxe 需要它们）
#          但 PlatformPei.c 里不再发布 DTB Extension HOB（那份地址是 GUID 常量表，会让 EnvDxe 崩）。
#          EnvDxe 于是走 EFI_NOT_FOUND 分支，vendor 栈恢复可用；探针仍是 2 秒周期 UI。
set -u
cd /mnt/d/本地项目-01/_k70port_extract/wsl || exit 1
TAG=keys42

python3 /mnt/d/本地项目-01/_tools/patch_pei42.py || exit 1

# 从 build_keys41.sh 派生，但把 DROP 列表里的 envdxe 去掉（EnvDxe 要装回来）
python3 - <<'PY'
import pathlib
src = pathlib.Path('/mnt/d/本地项目-01/_k70port_extract/wsl/build_keys41.sh').read_text()
s = src.replace(',"envdxe"', '')
s = s.replace('keys41', 'keys42')
# 不要 NULL PlatformPei：删掉我们之前插的那段强制 NULL 的 python 块
start = s.index('python3 - "$PKG" <<\'PYX\'')
end = s.index("PYX\n", start) + len("PYX\n")
s = s[:start] + s[end:]
pathlib.Path('/mnt/d/本地项目-01/_k70port_extract/wsl/build_keys42.sh').write_text(s)
print('wrote build_keys42.sh (EnvDxe back, real PlatformPeiLib)')
PY

bash build_keys42.sh "$TAG" || exit 1
bash pack_keys.sh /mnt/d/本地项目-01/_k70port_extract/qemu-fw/SILICIUM_UEFI-$TAG.fd "$TAG" || exit 1
cp /tmp/PlatformPei.c.bak42 /root/k70/uefi/Silicon/Qualcomm/QcomPkg/Library/PlatformPeiLib/PlatformPei.c
echo "=== keys42 done ==="
