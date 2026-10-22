#!/bin/bash
# keys41 = keys40 再摘掉 EnvDxe（它在我们驱动之后立刻挂住，导致事件循环永远跑不起来，
#          连周期 UI 定时器都不触发）。目标：让 DXE 派发能真正走到 BDS，看 ConIn 是否就绪。
set -u
cd /mnt/d/本地项目-01/_k70port_extract/wsl || exit 1
TAG=keys41

python3 - <<'PY'
import pathlib
p = pathlib.Path('/mnt/d/本地项目-01/_k70port_extract/wsl/build_keys38.sh')
s = p.read_text()
old = '''export DROP_JSON='["usb","xhci","pildxe","pilproxy","spss","tzdxe","charger","chg","sdcc","featureenabler","ddrinfo","limitsdxe","gpipdxe","gpidexe","ucdxe","rngdxe","tsens","clockdxe","displaydxe","rammanagerdxe"]'
'''
new = '''export DROP_JSON='["usb","xhci","pildxe","pilproxy","spss","tzdxe","charger","chg","sdcc","featureenabler","ddrinfo","limitsdxe","gpipdxe","gpidexe","ucdxe","rngdxe","tsens","clockdxe","displaydxe","rammanagerdxe","envdxe"]'
'''
assert old in s, 'drop list anchor not found'
pathlib.Path('/mnt/d/本地项目-01/_k70port_extract/wsl/build_keys41.sh').write_text(
    s.replace(old, new, 1).replace('keys38', 'keys41'))
print('wrote build_keys41.sh (EnvDxe dropped)')
PY

bash build_keys41.sh "$TAG" || exit 1
bash pack_keys.sh /mnt/d/本地项目-01/_k70port_extract/qemu-fw/SILICIUM_UEFI-$TAG.fd "$TAG" || exit 1
echo "=== keys41 done ==="
