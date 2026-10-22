#!/usr/bin/env bash
# 确认 FdtBlob 的 RAW section 真的进了 FV（FD 是压缩的，不能直接 grep）。
set -u
cd /root/k70/uefi/Build/vermeerPkg/DEBUG_CLANGPDB/FV || exit 1
echo "=== FV 目录 ==="
ls -l
echo
echo "=== 各文件里 FDT magic 出现次数 ==="
python3 - <<'PY'
import glob, os
MAGIC = b'\xd0\x0d\xfe\xed'
for p in sorted(glob.glob('*')):
    if not os.path.isfile(p):
        continue
    d = open(p, 'rb').read()
    n = d.count(MAGIC)
    if n or p.upper().endswith(('.FV', '.FD', '.FVI')):
        print(f"  {p:32s} {len(d):>9,} B  fdt_magic={n}")
PY
echo
echo "=== FV 里是否有 FILE FREEFORM 25462CDA 的 FFS 文件 ==="
python3 - <<'PY'
import glob, os, struct
GUID = bytes.fromhex('DA2C4625') + bytes.fromhex('1F21') + bytes.fromhex('DF47') + bytes.fromhex('AC1D259CFAA4E326')
for p in sorted(glob.glob('*')):
    if not os.path.isfile(p):
        continue
    d = open(p, 'rb').read()
    i = d.find(GUID)
    print(f"  {p:32s} guid_at={'-' if i<0 else hex(i)}")
PY
