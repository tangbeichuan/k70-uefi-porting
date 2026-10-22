#!/usr/bin/env bash
# nasm is only needed for x86 assembly in BaseTools; this port builds AARCH64 only.
# The NuGet feed for mu_nasm is unreachable here, so disable that external dependency.
set +e
BT=/root/k70/uefi/Mu_Basecore/BaseTools/Bin
[ -f "$BT/nasm_ext_dep.yaml" ] && mv "$BT/nasm_ext_dep.yaml" "$BT/nasm_ext_dep.yaml.disabled"
ls -1 "$BT"/*ext_dep* "$BT"/*.disabled 2>/dev/null

cd /root/k70/uefi || exit 1
. /root/k70/venv/bin/activate

echo "===== stuart_update ====="
stuart_update -c Platforms/Xiaomi/vermeerPkg/DeviceBuild.py 2>&1 | tail -12

echo "===== build ====="
python3 build_uefi.py -d vermeer -m 0 -r DEBUG 2>&1 | tail -45
echo "===== exit: $? ====="
