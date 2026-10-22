#!/usr/bin/env bash
# nuwa 对 UFSDxe 到底 patch 了什么？我们的 FV 用的是 stock 还是 patched？
set -u
R=/mnt/d/本地项目-01/_k70port_extract
STOCK=$R/port/Binaries/vermeer/QcomPkg/Drivers/UFSDxe/UFSDxe.efi
PATCH=$R/port/Binaries/vermeer/QcomPkg/Drivers/UFSDxe/UFSDxe.patched.efi
NSTOCK=$R/_nuwa/nuwa/QcomPkg/Drivers/UFSDxe/UFSDxe.efi

echo "=== sizes / sha ==="
ls -l "$STOCK" "$PATCH" "$NSTOCK" 2>/dev/null
sha256sum "$STOCK" "$PATCH" "$NSTOCK" 2>/dev/null
echo
echo "=== K70 stock vs nuwa stock identical? ==="
cmp -s "$STOCK" "$NSTOCK" && echo "IDENTICAL" || echo "DIFFER"
echo
echo "=== byte deltas nuwa stock -> nuwa patched ==="
python3 - "$NSTOCK" "$PATCH" <<'PY'
import sys
a=open(sys.argv[1],'rb').read(); b=open(sys.argv[2],'rb').read()
assert len(a)==len(b), (len(a),len(b))
i=0; runs=[]
while i<len(a):
    if a[i]!=b[i]:
        j=i
        while j<len(a) and a[j]!=b[j]: j+=1
        runs.append((i,a[i:j].hex(),b[i:j].hex())); i=j
    else: i+=1
print(f"{len(runs)} runs")
for o,x,y in runs:
    print(f"  @0x{o:06X} ({o})  {x}  ->  {y}")
PY
echo
echo "=== FDF/DSC 里 UFSDxe 的引用 ==="
grep -rn 'UFSDxe' /root/k70/uefi/Platforms/Xiaomi/vermeerPkg/vermeer.fdf /root/k70/uefi/Platforms/Xiaomi/vermeerPkg/vermeer.dsc 2>/dev/null | head
echo
echo "=== FV 里到底是哪个（看 FD 内是否含 patched 版本的特征字节）==="
ls -l /mnt/d/本地项目-01/_k70port_extract/qemu-fw/SILICIUM_UEFI-keys14.fd 2>/dev/null
