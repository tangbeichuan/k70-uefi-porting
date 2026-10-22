#!/bin/bash
set -e
F=/mnt/d/本地项目-01/K70-UEFI-build/keys-images/说明.txt
cat >> "$F" <<'EOF'

================================================================================
keys24 -> keys25  （2026-10-20 23:56）
--------------------------------------------------------------------------------
[keys24 真机] GUID 修复生效：
  [DTDUMP] hob list 0xC7007018 entries=104 guidhobs=7
  [DTDUMP] hob 3A06E1E8-...-4B476E2FF6A7 len=0x20   (GUID HOB 变体，数据 32 字节)
  [DTDUMP] ^^^ DTB EXTENSION HOB 3A06E1E8-61F6-11EB-BBED-4B476E2FF6A7 addr=0xA703A290
  [DTDUMP] dtb ext addr = 0xA703A290
  [DTDUMP] inside FD-Reserved(0xA7000000-0xA7FFFFFF) = YES
  [DTDUMP] entry[0..3] = 11EB61F63A06E1E8 A7F62FE474BEDBB8 49EF56D78EC2BD8D F8EBF87817639687
  [DTDUMP] as guid = 3A06E1E8-61F6-11EB-BBED-4B476E2FF6A7 (match DTBExtnHob=YES)   <== 修复成功
  说明：entry[1]/entry[2] 其实是紧邻的另一个 GUID（8EC2BD8D-56D7-49EF-...），不是指针。

[时序纠正] keys22/keys18 里 "DTBExtn protocol Status=Not Found" 是必然的，不是失败：
  APRIORI.inc 208 行，第 3 行 PcdDxe、第 6 行 EnvDxe、第 93 行 UFSDxe，末尾 RscDxe。
  我们的探针被插在 PcdDxe 之后 -> 第 2 个派发，EnvDxe(装 DTBExtn 协议) 还没跑。
  驱动派发是串行的，entry 里的 gBS->Stall 不会让别的驱动被派发 -> "6 秒后复检" 无意义。

[keys25 变更] 只改派发位置：探针插到 APRIORI 末尾（RscDxe 之后），去掉 Stall，保留 CpuDeadLoop 冻结屏。
  FD      SILICIUM_UEFI-keys25.fd  sha256 9e16a463c71fbabda16ed6768e13e5d5a4a4ee59557ffd04655ee68c3000faa5  3,145,728 B
  Mu-vermeer-keys25-marker.img     sha256 a3aa5b3c036a06063aae2f8ebf168fd66424a8d0cff333e04f31a6f108d22c2e  1,705,984 B
  Mu-vermeer-keys25.img            sha256 d548daafff492491b8fed5f1c5fb6550efe77a44532cbb8988147de4116bfb6f
  Mu-vermeer-keys25-v4.img         sha256 bc386c51a848f4f929d7fd0e8e2a4e793981e133653f6df2f33132f1fd9ae3b1  (不附加 DTB，别用)
  期望：屏上先出现完整 vendor 驱动列表(含 UFSDxe 的真实结果)，最后是我们的 DTDUMP 块并卡死。
EOF
wc -l "$F"; grep -c keys25 "$F"