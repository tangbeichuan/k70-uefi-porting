#!/bin/bash
set -e
F=/mnt/d/本地项目-01/K70-UEFI-build/keys-images/说明.txt
cat >> "$F" <<'EOF'

================================================================================
keys29  （2026-10-21 00:23）  探针提前到 EnvDxe 之前 + 扫 0x10005 接口候选
--------------------------------------------------------------------------------
[keys28 真机，00:20 三张照片] EnvDxe 不再 ASSERT 而是**崩溃**：
  Loading driver at 0x000C6C14000 … PcdDxe.efi
  Loading driver at 0x000C7091000 … EnvDxe.efi
  Synchronous Exception at 0x0000000C7097088
  PC 0x0000C7097088 (0x0000C7091000+0x00006088) [0] EnvDxe.dll
  PC 0x0000C7093814 (0x0000C7091000+0x00002814) [0] EnvDxe.dll
  PC 0x0000C70938F8 (0x0000C7091000+0x00002BF8) [0] EnvDxe.dll
  PC 0x0000C7092210 (0x0000C7091000+0x00001210) [0] EnvDxe.dll
  PC 0x0000C71FB9FC (0x0000C71FC000+0x000C9AC) [1] DxeCore.pdb
  V0 = 0x0000000A702AC94 0x0000000A702A978 ...

[反汇编定位] EnvDxe+0x6044 是一个“取接口”helper：
  6054: adrp x8,0xe000 ; ldr x8,[x8,#1632]   -> 全局 0xE660
  6068: ldr x9,[x8] ; cmp x9,#0x10005        -> 接口第 0 个 word 必须是 0x10005
  6080: ldr x8,[x8,#88]  (= +0x58)
  6088: ldr x8,[x8]      <- **崩在这里**
  6094: blr x8
  安装函数 EnvDxe+0x2ba8：
  2bc8: bl 0x6860                    (GetFirstGuidHob gEfiDtbExtensionHobGuid)
  2bd0: ldr x1,[x0,#24]              (HOB 数据 = 0xA703A290)
  2bdc: mov w2,#0x108 ; 2be8 bl 0x7c58   (CopyMem dst=0xe470, src=HOB数据, 264 字节)
  2c0c: blr ([gBS+0x5f8]+0x148)      (InstallMultipleProtocolInterfaces)
  → 结论：EnvDxe 期望 HOB 里的地址指向一个 **0x108 字节的接口结构**（word0 = 0x10005，
    +0x58 是子表指针）；我们给的是 GUID 常量表地址，于是装进去的是垃圾，第一次间接调用即崩。

[keys29] 探针回到第 2 个派发（PcdDxe 之后，EnvDxe 之前），新增 ScanWindowForVer()：
区窗口内按 8 字节步长找 u64 == 0x10005，命中则打印该地址与随后 4 个 word（最多 4 个命中）；
另外保留 ScanWindowForFdt()（FDT 魔数全扫）。末尾 CpuDeadLoop 冻结屏。
  只用来看：XBL 到底有没有发布真正的 0x108 接口。有 -> keys30 把 HOB 值改成它；没有 -> 自造接口。

  FD      SILICIUM_UEFI-keys29.fd  sha256 def9f82d9f75cf970f19303dac05a3edef012af2b8f94b9fa7997a227ec9c6ce  3,145,728 B
  Mu-vermeer-keys29-marker.img     sha256 330dd64a21a5577b61e0e518eebe74d55af8180f2001354e845ad509f6e82b7a  1,705,984 B
  Mu-vermeer-keys29.img            sha256 69b8b7e59afbdb88d4e44f28fcb4a56a41e4dd47e8537eca2381b8bf88d9d034
EOF
wc -l "$F"