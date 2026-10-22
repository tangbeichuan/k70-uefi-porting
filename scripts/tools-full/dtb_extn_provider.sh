#!/usr/bin/env bash
# 找 DTBExtnProtocol 的“提供者”驱动（不是消费者）。
set -u
cd /root/k70/uefi || exit 1
echo "=== Binaries 下所有 INF 名字里带 DTB/Dtb/Extn 的 ==="
find Binaries/vermeer -iname '*.inf' | grep -iE 'dtb|extn' | head -20
echo
echo "=== 各 .efi 里 'DTBExtn' 出现次数（消费者会有 'Failed to Locate'；提供者可能有 Install/Register）==="
for f in $(grep -ril 'DTBExtn' Binaries/vermeer --include=*.efi 2>/dev/null); do
  n1=$(strings -a "$f" | grep -c 'DTBExtn')
  n2=$(strings -a "$f" | grep -ci 'Failed to Locate DTBExtn')
  printf '  %-70s DTBExtn=%-3s failmsg=%s\n' "${f#Binaries/vermeer/}" "$n1" "$n2"
done
echo
echo "=== 全 Binaries 里带 'InstallProtocol' 且带 'Dtb' 的 efi ==="
for f in $(grep -ril 'dtb' Binaries/vermeer --include=*.efi 2>/dev/null); do
  if strings -a "$f" | grep -qiE 'InstallProtocolInterface|InstallMultipleProtocol'; then
    echo "  ${f#Binaries/vermeer/}"
  fi
done | head -20
echo
echo "=== QcomPkg/Extra.fdf.inc / Extra.dsc.inc 里的 DTB 相关行 ==="
grep -rn 'Dtb\|DTB' QcomPkg/Extra.fdf.inc QcomPkg/Extra.dsc.inc 2>/dev/null | head -20
echo
echo "=== 原厂 FV 里哪个 FFS 含 DTBExtn 且不含 'Failed to Locate'（候选提供者）==="
python3 - <<'PY'
import os
root='/mnt/d/本地项目-01/_k70port_extract/fv_dump'
for base, dirs, files in os.walk(root):
    for f in files:
        p=os.path.join(base,f)
        try:
            d=open(p,'rb').read()
        except Exception:
            continue
        if b'DTBExtn' in d:
            has_fail = b'Failed to Locate DTBExtn' in d
            print(f"  {p.replace(root+'/','')}  size={len(d)}  failmsg={has_fail}")
PY
