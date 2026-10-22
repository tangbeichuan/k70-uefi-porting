#!/bin/bash
set -e
F=/mnt/d/本地项目-01/K70-UEFI-build/keys-images/说明.txt
cat >> "$F" <<'EOF'

================================================================================
keys27  （2026-10-21 00:06）  修正 keys25/keys26 的构建事故
--------------------------------------------------------------------------------
[事故] keys25/keys26 是用 sed 从 build_keys23.sh 派生的，而“关掉 PEI scheduler/FV-list 路径”
这个修复从来没有进过任何 build 脚本——它只是 run_keys24.sh 里对 PlatformPei.c 的临时改动
（cp 备份 + trap 恢复）。于是 keys25/keys26 编译时完全没有这个修复，真机表现就是 keys23 的老崩溃：
  MMU: enabled
  Synchronous Exception at 0xA7102B98
（用户 00:06 那张照片拍到的就是这个。）

[教训] 任何“只活在一轮 run_*.sh 里的源码补丁”都必须下沉到 build_keysNN.sh 或独立的 patch 文件里，
否则下一次换 base 脚本就会静默丢失。keys27 起把该补丁写进 run_keys27.sh 并有 assert 保护。

[keys27 组成] keys23 的 CompareGuid 修复 + keys24 的 scheduler 关闭 + keys25 的“探针排在 APRIORI 末尾”
              + keys26 的 ScanWindowForFdt（FD 窗口全扫 FDT 魔数）
  FD      SILICIUM_UEFI-keys27.fd  sha256 b6f58554eebd16543fb59e22aa6741fe29b7a3f18604e5285b9b415065367caf  3,145,728 B
  Mu-vermeer-keys27-marker.img     sha256 b7e07415d2769f3ea56cca10914a03a8d67b12227dfaadd1fdb45f94b386ea96  1,705,984 B
  Mu-vermeer-keys27.img            sha256 df29470e52a129d033c28530a1677b9cf303ca3380d7d2ffbad1f055e0c9ebcb
  Mu-vermeer-keys27-v4.img         sha256 40bfc076ffda6459e4b0b12a27ab6439a842a474cb5d7029e27b0df42d195fff  (不附加 DTB，别用)
EOF
wc -l "$F"