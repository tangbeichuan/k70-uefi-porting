#!/bin/bash
set -e
F=/mnt/d/本地项目-01/K70-UEFI-build/keys-images/说明.txt
cat >> "$F" <<'EOF'

================================================================================
keys26  （2026-10-20 23:57）  keys25 + 全窗口 FDT magic 扫描
--------------------------------------------------------------------------------
[keys24 另一张照片] 暴力扫 GUID 的结果（截取）：
  [DTDUMP] scan 0xA7000000..0xA8000000 for DTBExtnHobGuid
  [DTDUMP] HIT guid at 0xA710DC38 / 0xA764BBA0 / ...
  [DTDUMP]  +0x00 11EB61F63A06E1E8 A7F62FE474BEDBB8   (GUID 本体 + 紧邻的下一个 GUID)
  [DTDUMP]  +0x10 49EF56D78EC2BD8D F8EBF87817639687
  [DTDUMP]  +0x20 4DD341374C19049F FAFD3FA8378B109C
  [DTDUMP]  +0x30 4F580893F8E21975 7AD7C6A9255BBE
  → 命中的都是 XBL rodata 里的“GUID 常量表”（相邻 16 字节就是另一个 GUID），
    不是 {GUID,值} 形式的 HOB 条目；因此暴力扫 GUID 无法区分，参考价值有限。
  → 注意某处命中后 +0x20 出现了 0000000000010001 / 0000000A71042C0 这类“计数+指针”形状的值，
    指针 0x…A71042C0 落在 FD 窗口内，值得用 FDT magic 扫描直接验证。

keys26 变更（相对 keys25，唯一新增）：
  探针新增 ScanWindowForFdt()：以 4 字节步长扫 0xA7000000..0xA7FFFFFF，
  命中 FDT magic（大端 0x00D00DFEED，按小端 UINT32 读为 0xEDFE0DD0）就打印
  “FDT magic at 0x<addr> totalsize=… ver=…”，最多打印 8 个，最后打印 hits=N。
  其余不变：驱动仍在 APRIORI 末尾、EnvDxe/UFSDxe 先跑、末尾 CpuDeadLoop 冻结屏。

  FD      SILICIUM_UEFI-keys26.fd  sha256 2c4c96633487de8231980b91e2dd2bf8cde397c5cef88ceae2bc700c2fbf083c  3,145,728 B
  Mu-vermeer-keys26-marker.img     sha256 979d1dcf79e81c4f8b568ffed43b581fbd19e5fd328c0e3835d7fc77faf706ac  1,705,984 B
  Mu-vermeer-keys26.img            sha256 4f536d407657c70d9dea5def8a61f0a5acf711ccc88ae1c50d6772d25fd8e467
  Mu-vermeer-keys26-v4.img         sha256 e5fc2061e5936fccfaadf3e1e51b81d2ffd163def5e48284dbe4df4550c54fbf  (不附加 DTB，别用)
EOF
wc -l "$F"