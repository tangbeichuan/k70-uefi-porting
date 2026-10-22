#!/bin/bash
set -e
F=/mnt/d/本地项目-01/K70-UEFI-build/keys-images/说明.txt
cat >> "$F" <<'EOF'

================================================================================
keys28  （2026-10-21 00:18）  保住 Scheduler Interface HOB，只跳过会飞的 CreateFvList
--------------------------------------------------------------------------------
[keys27 真机，用户 00:16 照片] 屏上原文（末尾两行）：
  Loading driver at 0x000C6C14000 EntryPoint=0x000C6C15?EC PcdDxe.efi
  Loading driver at 0x000C7091000 EntryPoint=0x000C7092000 EnvDxe.efi
  ASSERT_EFI_ERROR (Status = Not Found)
  ASSERT AutoGen.c +507: !EFI_ERROR (Status)
  → keys27 顺利过了 PEI（MMU: enabled 之后正常进 DxeCore、HOBLIST=0xC7007018），
    但 EnvDxe 的入口返回 EFI_NOT_FOUND，被 AutoGen.c 的 ASSERT_EFI_ERROR 抓住。

[根因] keys24/keys27 用 `if (0)` 把整个 scheduler 分支关死了，连
  BuildGuidDataHob(gEfiSchedulerInterfaceHobGuid, …) 也没建。而 EnvDxe.efi 内嵌
  gEfiSchedulerInterfaceHobGuid（文件偏移 0xe340），却**没有** gEfiFvListHobGuid ——
  它要的是 Scheduler Interface HOB，不是 FV list。
  GUID 内嵌实测（EnvDxe.efi）：
    InfoBlk 90A49AFD-422F-08AE-9611-E788D3804845 -> 0xe018 / 0xe118
    Shim    BEDAEABC-5E70-4D66-9733-213D072B9D04 -> 0xe0c8
    SchedulerIface 8EC2BD8D-56D7-49EF-8796-631778F8EBF8 -> 0xe340
    DtbExtension 3A06E1E8-61F6-11EB-BBED-4B476E2FF6A7 -> 0xe098
    DtbExtnProto 0389B776-625F-11EB-83BE-C741A913DE34 -> 0xe1c8
    FvList 12DBD93D-402A-416E-EC20-5F80CF5F7FE7 -> NOT FOUND
    Prodmode D5F8D706-D602-4F39-969D-A04FE2BB7F61 -> NOT FOUND

[keys28 补丁] PlatformPei.c 的 BuildXblHobs 里：
  保留 BuildGuidDataHob(&gEfiSchedulerInterfaceHobGuid, …)；
  删掉 EFI_KERNEL_PROTOCOL *SchedulerProtocol = … 与 UINTN *FvListAddr = CreateFvList(SchedulerProtocol)
  以及随后的 FV-list HOB 建立（EnvDxe 不需要它）。
  即：Scheduler HOB 建、CreateFvList 不调。

  FD      SILICIUM_UEFI-keys28.fd  sha256 704a913445d002948b98136a681337e207237487489208356a2f4e9e90f26665  3,145,728 B
  Mu-vermeer-keys28-marker.img     sha256 5f6350515425fa7475f93a3ab04d765af971cda2e67d2d4febd6301bba706cc5  1,705,984 B
  Mu-vermeer-keys28.img            sha256 725700f3a52d2b159c1f5201526676d39c04facaae548773a42aed014e39e169
  Mu-vermeer-keys28-v4.img         sha256 3d0af06240ef6fc8b432d9cee82810af8b7b587536ba7a3cef261ce731431085  (不附加 DTB，别用)
EOF
wc -l "$F"