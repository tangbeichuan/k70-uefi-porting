#!/usr/bin/env bash
# 检查 vermeerPkg/FdtBlob 里的 DTB 是否含 UFS 相关节点/属性；并定位 DtPlatformDtbLoaderLib。
set -u
cd /root/k70/uefi || exit 1
F=Platforms/Xiaomi/vermeerPkg/FdtBlob/sm8550-xiaomi-vermeer.dtb
echo "FdtBlob: $F  size=$(stat -c %s "$F")"
python3 - "$F" <<'PY'
import sys
d = open(sys.argv[1], 'rb').read()
pats = [b'init_speed_params', b'perf_speed_params', b'timeout_values',
        b'ufs0_vcc', b'ufshc', b'ufsphy', b'qcom,ufs-phy-qmp-v4-kalama',
        b'ufs0', b'splash_region', b'/soc', b'pmic']
for p in pats:
    n = d.count(p)
    print(f"  {p.decode():32s} {n}")
print("magic:", d[:4].hex(), "totalsize:", int.from_bytes(d[4:8], 'big'), "actual:", len(d))
PY

echo
echo "--- 对比 Resources/DTBs/vermeer.dtb ---"
G=/mnt/d/本地项目-01/_k70port_extract/port/Resources/DTBs/vermeer.dtb
[ -f "$G" ] || G=/mnt/d/本地项目-01/_k70port_extract/Resources/DTBs/vermeer.dtb
if [ -f "$G" ]; then
  echo "$G size=$(stat -c %s "$G")  sha=$(sha256sum "$G" | cut -d' ' -f1)"
  echo "FdtBlob sha=$(sha256sum "$F" | cut -d' ' -f1)"
  cmp -s "$G" "$F" && echo "  IDENTICAL" || echo "  DIFFERENT"
fi

echo
echo "--- DtPlatformDtbLoaderLib 位置 ---"
find . -name 'DtPlatformDtbLoaderLib.inf' -not -path './Build/*' 2>/dev/null | head
find . -path './Build' -prune -o -name 'DtPlatformDtbLoader*.c' -print 2>/dev/null | head
echo
echo "--- DtPlatformDxe.inf 内容 ---"
sed -n '1,60p' Mu_Basecore/EmbeddedPkg/Drivers/DtPlatformDxe/DtPlatformDxe.inf 2>/dev/null
