# keys143 报告 — UsbConfigDxe 崩溃根因 + HAL IOMMU 放回 FV

日期：2026-10-22 01:40（Asia/Shanghai）
构建：后台任务 pwsh-566 rc=0，日志 `_tools/b143.log` 尾 `PROGRESS - Success`

## 1. 交付物

| 产物 | 路径 | sha256 | 大小 |
|---|---|---|---|
| FD | `_k70port_extract/qemu-fw/SILICIUM_UEFI-keys143.fd` | `8ae2da83627373ac0d0eeea5bf89332543fb99f813ab719e700115b3270f6587` | 4,194,304 B |
| 镜像 | `K70-UEFI-build/Mu-vermeer-keys143.img` | `c1dc3baef6701062688abcb80f8bba1fda663d22455e73a73fe69efc0cae6fdd` | 1,763,328 B |
| 改名交付 | `K70-UEFI-build/K70-keys143-USB-CONFIG-2.img` | 同上 `c1dc3bae…` | 1,763,328 B |

keys140/141/142 的全部成果保留（见 §4）。

## 2. 根因（精确到指令）

崩溃 PC = `UsbConfigDxe.dll + 0x3FF0`。反汇编（objdump 地址 = RVA = 文件偏移；.text VA/raw=0x1000，size 0x12000）：

```
03f68 adrp x8,0x13000 ; ldr x8,[x8,#0x768]      ; gIommu 全局（0x13768），BSS 初值 0
03f70 cbnz x8,0x41c8                             ; 已定位则跳过
03f78 adrp x8,0x13000 ; ldr x8,[x8,#0x6e8]      ; gBS
03f80 ldr x8,[x8,#0x140]                         ; -> LocateProtocol
03f84 adrp x0,0x13000 ; add x0,x0,#0x1b8        ; GUID 54B6D3B4-5D33-4F91-8600-6C41D5DEB19A (HAL IOMMU)
03f8c adrp x2,0x13000 ; add x2,x2,#0x768        ; &gIommu
03f94 mov x1,xzr ; 03f98 blr x8                  ; Status = LocateProtocol(GUID, NULL, &gIommu)
03f9c mov w8, w0                                 ; ← 状态被截断到 32 位
03fa0 stur w8,[x29,#-0x24]
03fa4 ldur w8,[x29,#-0x24]                       ; ← w8 零扩展到 64 位，bit63 恒为 0
03fa8 tbz  x8,#0x3f,0x3fe8                       ; ← BUG：EFI_ERROR() 检查失效，错误分支成死代码
03fe8 adrp x8,0x13000 ; ldr x8,[x8,#0x768]       ; x8 = gIommu = NULL
03ff0 ldr x8,[x8,#0x8]                           ; ★崩溃：FAR = 0x8，X8 = 0
```

- 屏上 `X0 = 0x8000000000000E` = EFI_NOT_FOUND，正是 `LocateProtocol(HAL IOMMU)` 的返回值；`PC 0x…+0x3FF0`、`X8=0` 与上表逐项吻合。
- **vendor 的错误分支本身是正确的**：`03fb0` 把 0 写回 `[0x13768]`，打印 `"Failed to open HAL IOMMU protocol Status = (0x%x)"`（格式串 @0x10109），然后 `b 0x41c4` 继续 per-core 循环。也就是说**按厂商设计 IOMMU 是可选的**，只要它不是 NULL 就继续。
- 编译出来的 `tbz x8,#0x3f` 是对 `w8` 值（而非 64 位 EFI_STATUS）做位 63 测试，属于编译器在 `EFI_ERROR((EFI_STATUS)w8)` 上的边界行为；结果是「没有 IOMMU 协议」这一合法情形会直接空指针崩溃。
- 真正缺的是 **HAL IOMMU 协议的生产者**：keys142 的 Guid.xref 里没有 HALIOMMUDxe（keys70 血缘把 `HALIOMMUDxe` 硬注释成 `# [keys70-hard] …`，理由记录为"本次直接用自研直读驱动"）。

## 3. keys143 的两处改动（都可回退）

### (a) 把厂商 HALIOMMUDxe 放回 FV（主修）
- `Include/DXE.inc:54`：`# [keys70-hard] INF …/HALIOMMUDxe.inf` → `  INF …`（DXE.inc 才是 FV 放置权威清单）。
- `Include/APRIORI.inc:37`：同样解注释，恢复派发。
- APRIORI 顺序经实测已满足「provider 先于 HALIOMMU」：`APRIORI.inc:4` = `INF vermeerPkg/Drivers/VermeerDtbExtnDxe/VermeerDtbExtnDxe.inf`（keys140 血缘的 patch_extn136.py 早就插在块首），HALIOMMU 在 :37。HALIOMMU 是靠 DTBExtn 解析 `/soc/iort` 的，必须先有我们的 provider。
- HALIOMMU 的 depex（`HALIOMMUDxe.depex` 216 B）解码为 12 个 arch 协议全 AND（Bds/Cpu/Metronome/MonotonicCounter/RealTimeClock/Reset/Runtime/Security/Timer/VariableWrite/Variable/Variable2/WatchdogTimer），DXE Core 自带 ⇒ 进 FV 即可 dispatch，无需改动 depex。
- HALIOMMU 用到的 DTBExtn 槽位（实测）：+0x28 子节点数、+0x30 GetNode、+0x58 取属性、+0x68 子名长度、+0x70 子名列表、+0x98、+0xa0 取 u32、+0xa8 取属性值 —— 我们的 provider（keys140）全部已实现。
- HALIOMMU 读的 DT 属性经 strings 交叉核对，我们的 `/soc/iort` 全有：`NumberofIORTNodes`、`Signature/Revision/Checksum/OEMID/OEMTableID/OEMRevision/CreatorID/CreatorRevision`、`Series` 与 `instance_handles`、每个 SMMU 节点的 `Type/Revision/Reserved/NumberofMappings/BaseAddress/Span/Flags/Model/NumContextInterrupts/NumPMUInterrupts/NSGIRPT_GSIV/NSGIRPT_FLAGS/NSGCFGIRPT_GSIV/NSGCFGIRPT_FLAGS/ContextInterrupts/ContextInterruptFlags/PMUInterrupts/PMUInterruptFlags/SIDMAPPING/phandle`、client 节点 `DevObjectName` + `SIDMappings/*` 子节点（InputBase/NumIDs/OutputBase/Flags/OutputReference）。⇒ **DT 侧不需要补任何东西**。

### (b) 防御性 4 字节补丁（HALIOMMU 万一失败也不崩）
- 文件 `Binaries/vermeer/QcomPkg/Drivers/UsbConfigDxe/UsbConfigDxe.patched.efi`，偏移 `0x3FA8`：
  `0xB6F80208`（`tbz x8,#0x3f,0x3fe8`，死代码）→ `0x36F80208`（`tbz w8,#0x1f,0x3fe8` ≈ `EFI_ERROR()`），
  于是错误分支生效：清 gIommu、打印一行日志、继续执行。
- 构建脚本自带备份/还原：`build_keys143.sh` 在 restore() 里把 `UsbConfigDxe.patched.efi` 还原成原厂字节（构建后实测 `0x3FA8 = B6F80208` ✓，未来 keys144 不会带着补丁）。
- 验证：`FVMAIN.Fv` 里 `36F80208` 命中 1 次，且位于 UsbConfigDxe FFS 的 PE 偏移 0x3FA8（FFS 内 0x4024）✓。

### 构建血缘
- `_tools\patch_usb143.py`（幂等；打印 `PATCH_USB143 OK`）
- `_tools\run143.sh`：sed 142→143 生成 `wsl/build_keys143.sh` + `run_keys143.sh`；patch 链
  `patch_usb126 → patch_usb130 → patch_pmicstub127 → patch_usb141 → patch_acpi142 → patch_usb143 → patch_fat137`；
  不含 `patch_nopmic138.py`（真 PMIC），restore trap 还原 5 个文件（含 UsbConfigDxe.patched.efi）。
- `_tools\verify143.sh` / `verify143b.sh` / `verify143c.sh`：产物与 FV 内字节验证。

## 4. 验证结果（全部通过）

- **Guid.xref**：新增 `9A00771F-36D4-4DD5-8916-C48ED9B16B86 HALIOMMU` ✓；keys142 的 `9622E42C… AcpiTableDxe`、`CD823A4D… UsbConfigDxe`、`0A134F0E… UsbInitDxe`、`5AF77F10… UsbMsdDxe`、`94F8A6A7… UsbfnDwc3Dxe`、`3F6C1D92… VermeerPmicVerStubDxe`、`5776232E… PmicDxe`、`5B21E7C4… VermeerDtbExtnDxe`、`9C5E7A31… VermeerLogDiskDxe`、`4F7A1C2E… VermeerMenuDxe` 全在；`UFSDxe` 仍 0 ✓。
- **FVMAIN.inf 放置行**：25 UsbfnDwc3Dxe、88 UsbMsdDxe、89 UsbConfigDxe、90 UsbInitDxe、100 AcpiTableDxe、HALIOMMU 在模块表第 30 项（DXE.inc:54 顺序）。
- **FVMAIN.Fv（5,955,584 B）**：HALIOMMU GUID ×3（@0x1a4 APRIORI 表、@0x17c468 FFS 头、@0x189578 内嵌 .data）；HALIOMMU FFS 147,726 B；AcpiTableDxe ×1 @0x3eecc0；UsbConfigDxe ×3；VermeerDtbExtnDxe ×2；PmicDxe ×3。
- **DTB**：FV 内 FILE FREEFORM 与 `xbl_ufs.dtb` 逐字节相同（57,217 B，sha256 `78c55f2e…`，1 份）。
- **provider 断言串**：`"vermeer dtb-extn provider"` 1、`+0x28 count(` 1、`+0x68 sizes(` 1、`+0x70 names(` 1、`selftest vadc` 2。
- **HALIOMMU 加固补丁**：UsbConfigDxe FFS 内 0x36F80208 命中且原值不在该 FFS 内 ✓。
- **LogDisk/FAT**：构建脚本自检全 OK（volume ready / FAT16 geometry / selfcheck / BOOTLOG / K70 LOGDISK）。

## 5. 上机预期 & 观察点

好的走向（预期）：
1. `Loading driver at … HALIOMMUDxe.efi` 出现在 UsbConfigDxe 之前（APRIORI :37 vs :174）。
2. HALIOMMU 通过我们的 DTBExtn 读 `/soc/iort`，**不应**出现 `Locate DTBExtnProtocol failed: %r` 或 `%a: Error in getting %s with return = %d`。
3. UsbConfigDxe 的 `LocateProtocol(HAL IOMMU)` 返回 Success ⇒ **不再有 0x3FF0 崩溃**，`X4=0x9A` 那条也随之中止。
4. 继续看到 `UsbConfigLibOpenProtocols: PMI version (0x47)` 以及后续 USB device-mode 链路；`UsbInitDxe` 应该开始 dispatch（它依赖 UsbConfigDxe 装的 `E722B03F`）。

需要回报给我的关键行（有就贴给我）：
- 任何 `Locate DTBExtnProtocol failed` / `Error in getting` / `Failed to open HAL IOMMU protocol Status =`；
- 若仍崩溃：`Synchronous Exception at 0x…`、`PC 0x…+0x…  [x] 哪个.dll`、`X0/X1/X8`；
- HALIOMMU 自己的日志（它可能打印 SMMU/BBM/`WARN: Not BBM Safe Region` 之类）；
- 是否出现 `[FAT16] volume ready` / PC 上是否出现盘符。

## 6. 风险与回退

- **风险 1**：HALIOMMU 在不完全 stock 的环境里可能自身崩（例如缺 `gEfiKernelProtocolGuid` 生产者、Mu 的 InfoBlkHob/ShimLibraryHob 语义不同、SMMU 配置对非 stock 内存布局不友好）。表现：异常 PC 指向 `HALIOMMU.dll`，或启动卡在 USB 之前。→ 回退方案 **keys143b = keys143 去掉 (a) 只留 (b)**：只需在 `patch_usb143.py` 里跳过两处解注释（或 `run143.sh` 增加 `nohal` 分支），构建约 4 分钟，可立即出。
- **风险 2**：加固补丁改变的是 vendor 二进制行为（把"错误分支死代码"修活），语义上等价于厂商源码意图，风险很低，且该分支只在"没有 IOMMU 协议"时生效。
- **风险 3**：`DisableUsbClocks: ClockProtocol unavailable` 仍会打印（Clock 协议不在 FV，与本次无关；vendors 的 usb 时钟路径依赖它，若后面 USB 功能仍不完整，这条是下一个嫌疑点）。

## 7. 未改动项（刻意保持）

- `vermeer.dsc` 未动；`AcpiPlatformDxe`/`AcpiTables.inf` 仍注释；`patch_nopmic138.py` 未启用；`UFSDxe`/`PmicDxeLa.patched` 状态不变；keys140 的 provider 与 keys141 的 UsbConfigDxe 放置、keys142 的 AcpiTableDxe 全部保留。

---

# keys143b（对照构建，NO_HAL=1）与 USB device-mode 链分析

## 1. keys143b 是什么

= keys143 的改动里**只保留 (b) UsbConfigDxe.patched.efi 的 EFI_ERROR 加固补丁**，跳过 (a) HALIOMMUDxe 的两处解注释（`patch_usb143.py` 的 `NO_HAL=1` 分支）。用于真机时把"IOMMU 是否存在"和"vendor 崩溃 bug"两个变量拆开归因：

- 若 **keys143**（有 IOMMU + 加固）正常 → 双保险；
- 若 **keys143** 在 HALIOMMU 内部崩、而 **keys143b** 正常 → 说明 IOMMU 在此环境不安全，后续血缘应保持 NO_HAL；
- 若 **keys143** 仍崩在 0x3FF0 之外的新点 → 与 IOMMU 无关，看新 PC。

血缘：`_tools/run143b.sh`（从 build_keys143.sh/run_keys143.sh sed 143→143b，`export NO_HAL=1`；patch 链同 keys143：usb126→usb130→pmicstub127→usb141→acpi142→usb143(NO_HAL)→fat137；restore trap 同样备份/还原 `UsbConfigDxe.patched.efi`）。

## 2. keys143b 产物

| 项 | 值 |
|---|---|
| FD | `/root/k70/uefi/../_k70port_extract/qemu-fw/SILICIUM_UEFI-keys143b.fd`，sha256 `cdb7a41a3fd1273709a759783c96d06628b5bdca565e97bbae714ed1cb81d04f`，4,194,304 B |
| 镜像 | `K70-UEFI-build/Mu-vermeer-keys143b.img`，sha256 `8f1c42bb1e1526caaeb5e35cffd231b961c408e50f07b88c6262f79b4d3d6b39`，1,753,088 B |
| 交付副本 | `K70-UEFI-build/K70-keys143b-NO-HALIOMMU.img`（sha 同上） |

验证（`_tools/verify143b_img.sh` + `fixxref143b.sh`）：

- `Build/vermeerPkg/DEBUG_CLANGPDB/FV/Guid.xref`：**无 HALIOMMU**（`grep -i halio` 空）✓；
- keys142 全套仍在：AcpiTableDxe / UsbConfigDxe / UsbInitDxe / UsbMsdDxe / UsbfnDwc3Dxe / UsbDeviceDxe / VermeerPmicVerStubDxe / PmicDxe / VermeerDtbExtnDxe / VermeerLogDiskDxe / VermeerMenuDxe；UFSDxe 0；
- `FVMAIN.Fv` 5,808,128 B：`0802f836`（tbz w8,#0x1f 加固）命中 1 处；UsbConfigDxe FFS（86,170 B，MZ@0x7c）0x3FA8 起 = `0802f836` ✓；
- FV 内 DTB 仍与 `xbl_ufs.dtb` 逐字节相同（57,217 B，sha256 `78c55f2e…`，1 份）；
- 构建结束后 UsbConfigDxe.patched.efi 已被 restore trap 还原（0x3FA8 = `B6F80208`）。

## 3. USB device-mode 链 depex 全表（EFI_DEPEX 字节解码）

| 驱动 | depex 协议 | 现在 FV 里的生产者 | 结论 |
|---|---|---|---|
| UsbConfigDxe | ChipInfo `B0760469`、SPMI `FA5F306B`、SMEM `F4E5C7D0`、PlatformInfo `157A5C45`、AcpiSDT `EB97088E`（全 AND） | ChipInfoDxe / SPMIDxe(`2A7B4BEF SPMI`) / SmemDxe(`F541D663`) / PlatformInfoDxeDriver(`B105211B`) / AcpiTableDxe(`9622E42C`) | keys142 起全部满足 |
| UsbInitDxe | 仅 `E722B03F`（UsbConfig 协议） | **UsbConfigDxe 自己 InstallMultipleProtocolInterfaces 装** | 满足 |
| UsbfnDwc3Dxe | 16 项 AND：15 个 arch 协议 + SPMI `FA5F306B` + SMEM `F4E5C7D0` | SPMIDxe / SmemDxe | 满足；**depex 不含 HAL IOMMU** |
| UsbDeviceDxe | SPMI + SMEM | 同上 | 满足 |
| UsbMsdDxe | `TRUE`（2 B depex，无协议依赖） | — | 只要被 FV 放置就会 dispatch |
| UsbPwrCtrlDxe | `TRUE` | — | 同上 |
| UsbBusDxe | 无 .depex 文件 | — | 同上 |

**结论：USB device-mode 链上 depex 侧没有任何缺生产者，接下来不要再往 depex/stub 方向找。**

## 4. HAL IOMMU 依赖面（回答"UsbfnDwc3Dxe 是否也要 HAL IOMMU"）

- 二进制 GUID 引用统计（`usb144_chain.py`）：`54B6D3B4…`（HAL IOMMU）在整个 USB 链里**只有 UsbConfigDxe 引用**；UsbfnDwc3Dxe / UsbDeviceDxe / UsbInitDxe / UsbMsdDxe / UsbBusDxe / UsbPwrCtrlDxe 均**不引 HAL IOMMU**。
- 因此 keys143 里把 HALIOMMU 放回 FV，唯一受益者是 UsbConfigDxe；keys143b（不放 HALIOMMU + 修 EFI_ERROR bug）同样能让 UsbConfigDxe 越过错觉的 0x3FF0。

## 5. 我们的 DTBExtn / DT 是否够这条链用（重要）

- 会真正调用 DTBExtn 的只有：**UsbConfigDxe、UsbfnDwc3Dxe、UsbDeviceDxe**（二进制含 `0389B776…` GUID）。UsbInitDxe/UsbMsdDxe/UsbBusDxe/UsbPwrCtrlDxe 只是链接了公共库、实际不 Locate DTBExtn。
- 它们读的 DT 只有两条路径 + 一个属性（`usb144_dtb.sh` / `usb144_str.sh` 反汇编+字符串实测）：
  - `/soc/usb0/hs_phy_cfg`，属性 `table`
  - `/soc/usb0/ss_phy_cfg`，属性 `table`
- 我们 `xbl_ufs.dtb` 里**都存在**（`/soc/usb0` 在 DTS 第 1567 行，`compatible="qcom,usb"`；`hs_phy_cfg.table` = `<0xffffffff 0x00 …>` 4 组哨兵对，`ss_phy_cfg.table` = `<0x88e8008 0x01 …>` 大量真实寄存器对）⇒ **DT 侧不需要补**。
- 槽位需求：UsbfnDwc3Dxe 用到 +0x28/+0x30/+0x68/+0x70/+0x90/+0x98/+0xa8；UsbDeviceDxe 用到 +0x68/+0x70/+0x90/+0x98 → **keys140 provider 已全部实现**。
- 注意 `hs_phy_cfg.table` 全是 `0xffffffff` 哨兵（vendor 语义="跳过此项"），若后续 USB 高速 PHY 行为异常，这是第一个要查的 DT 数据点（不是缺失，是值本身如此）。

## 6. 下一个嫌疑：Clock 协议（不是 depex，是运行期 Locate）

- UsbConfigDxe 运行期 Locate 的 17 个 GUID 里有 `gEfiClockProtocolGuid = 241AFAE6-885F-4F6C-A7EA-C28EAB79C3E5`（.data @0x130f8）；当前 FV 里 **241AFAE6 出现 0 次** ⇒ 无人生产 ⇒ keys142 屏上 `DisableUsbClocks: ClockProtocol unavailable` 的来源。
- 生产者候选 = `ClockDxe.efi`（`Binaries/vermeer/QcomPkg/Drivers/ClockDxe/ClockDxe.efi`，204,800 B，FILE_GUID `4DB5DEA6-5302-4D1A-8A82-677A683B0D29`），其 depex 只有 **DALSys + ChipInfo**（都已满足），且**不含 DTBExtn GUID、源码无 `/soc` 路径串** ⇒ 放回 FV 技术上很干净、不需要 DT 支持。
- 它被 keys 血缘 DROP（build_keys143b.sh DROP 列表里有 `"clockdxe"`，DXE.inc 对应行被 `# [keysNNN-drop]` 注释）。若真机上 USB 若因时钟没使能而不枚举，**keys144 首选 = 解注释 ClockDxe**（与 HALIOMMU 同型的一行修复）。
- 目前证据表明"时钟缺失被 vendor 优雅降级"（只打印一行 warning、不崩），所以它是"功能可用性"问题而非"崩溃"问题——先看 keys143/143b 真机能不能过 0x3FF0。

## 7. 待真机回报的关键行

- keys143：`Loading driver at … HALIOMMUDxe.efi`／`Failed to open HAL IOMMU protocol Status =`／HALIOMMU 自己的 SMMU 日志／是否还有 `Synchronous Exception`；
- keys143b：是否出现 `Failed to open HAL IOMMU protocol Status = (0x800000000000000E)` 后**继续往下走**（这正是加固补丁生效的标志）；
- 两者都应看：UsbInitDxe/UsbfnDwc3Dxe/UsbDeviceDxe 是否 dispatch、`[UI]`/LogDisk 是否仍在、PC 是否出现 `K70 LOGDISK` 盘符。

---

# keys144（基线 keys143b + 恢复 ClockDxe）

## 1. 做了什么

基线 = **keys143b**（NO_HAL：HALIOMMUDxe 保持注释；UsbConfigDxe.patched.efi 保留 `0x3FA8: tbz w8,#0x1f` 加固），只加一件事：**把 ClockDxe 放回 FV 并在 UsbConfigDxe 之前派发**，以生产 `gEfiClockProtocolGuid = 241AFAE6-885F-4F6C-A7EA-C28EAB79C3E5`，消除 `DisableUsbClocks: ClockProtocol unavailable`。

- `_tools/patch_clock144.py`：
  1. `Include/DXE.inc:97` 解注释 → `  INF Binaries/vermeer/QcomPkg/Drivers/ClockDxe/ClockDxe.inf`；
  2. `Include/APRIORI.inc` 中删除旧 ClockDxe 行并**插到 UsbConfigDxe 行之前**（幂等；`patch_usb141.py` 之后运行，插入点稳定）。
- `_tools/run144.sh`：从 build_keys143b.sh / run_keys143b.sh sed 143b→144，`export NO_HAL=1`，patch 链 = usb126→usb130→pmicstub127→usb141→acpi142→usb143(NO_HAL)→**clock144**→fat137；支持 `probe`。
- probe 实测：DXE.inc:97 已 active；APRIORI `172 stub → 173 ClockDxe → 174 UsbConfigDxe`；HALIOMMU 两处仍是 `# [keys70-hard]`；UsbConfigDxe 0x3FA8 构建期 `36F80208`、结束后还原 `B6F80208`；patch_fat137 全 OK。

## 2. 产物

| 项 | 值 |
|---|---|
| FD | `_k70port_extract/qemu-fw/SILICIUM_UEFI-keys144.fd` sha256 `b0893529d4653636b6452ee1d3bfbb139026862d732dbb751430c77cf0293f7e`（4,194,304 B） |
| 镜像 | `K70-UEFI-build/Mu-vermeer-keys144.img` sha256 `d34e629425ff6ec0a811b6a07342e44c0190192182b8738fb0d4301b3d4ae08e`（1,787,904 B） |
| 交付副本 | `K70-UEFI-build/K70-keys144-CLOCKDXE.img`（sha 同上） |

## 3. 验证（`_tools/verify144.sh` + `verify144_bytes.sh`）

- `Guid.xref`：**`4DB5DEA6-5302-4D1A-8A82-677A683B0D29 ClockDxe` 出现** ✓；keys142 全套仍在（AcpiTableDxe / UsbConfigDxe / UsbInitDxe / UsbMsdDxe / UsbfnDwc3Dxe / UsbDeviceDxe / VermeerPmicVerStubDxe / PmicDxe / VermeerDtbExtnDxe / VermeerLogDiskDxe / VermeerMenuDxe）；**HALIOMMU 0**（保持 keys143b 语义）；**UFSDxe 0**。
- `FVMAIN.inf` 放置行：25 UsbfnDwc3Dxe、**68 ClockDxe**、88 UsbMsdDxe、**89 UsbConfigDxe**、90 UsbInitDxe、100 AcpiTableDxe ⇒ FV 顺序也保证 ClockDxe 在 UsbConfigDxe 之前。
- `FVMAIN.Fv` 6,012,928 B：ClockDxe FFS GUID ×3（FFS 头 + APRIORI 表 + 内嵌 .data），ClockDxe FFS 204,890 B；**`gEfiClockProtocolGuid 241AFAE6…` 出现 10 次（构建前为 0 次）**；HALIOMMU GUID 仍只有 UsbConfigDxe 消费的 1 处（无生产者，符合 NO_HAL）；加固补丁 `0802f836` 命中 1 处，UsbConfigDxe FFS 0x3FA8 = `0802f836` ✓。
- FV 内 DTB 仍与 `xbl_ufs.dtb` 逐字节相同（57,217 B，sha256 `78c55f2e…`，1 份）✓。
- 构建后源码树已还原：DXE.inc:97 / APRIORI.inc:63 都回到 `# [keys47-drop] … ClockDxe.inf`（patch 幂等，可重复构建）。

## 4. keys144b 回退（若 ClockDxe 真机自己崩）

**keys144b = 直接用 keys143b 镜像，不重新构建**，路径与 sha 已保留、未覆盖：

- `K70-UEFI-build/K70-keys143b-NO-HALIOMMU.img`（= `Mu-vermeer-keys143b.img`）sha256 `8f1c42bb1e1526caaeb5e35cffd231b961c408e50f07b88c6262f79b4d3d6b39`，1,753,088 B。
- ClockDxe 的 depex 只有 `AE37B942`(DALSys) + `B0760469`(ChipInfo)，两者在 FV/运行时均满足，理论安全；若它仍崩（日志出现 `Loading driver at … ClockDxe.efi` 后跟 `Synchronous Exception`，PC 指向 `ClockDxe.dll`），回退即刷 keys143b，代价为零。

## 5. 真机观察点（keys144）

1. `Loading driver at … ClockDxe.efi` 出现在 UsbConfigDxe 之前；
2. `DisableUsbClocks: ClockProtocol unavailable` **应消失**；可能出现时钟使能相关日志（ClockDxe 若打印 `Unable to turn ON clock` 说明 DTB 时钟节点/ NPA 侧仍缺，但不应崩溃）；
3. `Failed to open HAL IOMMU protocol Status = (0x800000000000000E)` 后**继续往下走**（说明 0x3FA8 加固生效，且没有 HALIOMMU）；
4. 后续应看到 UsbInitDxe/UsbfnDwc3Dxe/UsbDeviceDxe dispatch、`[UI]`/LogDisk 仍在、PC 端出现 `K70 LOGDISK` 盘符。

## keys145（HALIOMMU 恢复 + UsbConfigDxe 0x53CC NULL 守卫）

### 为什么做这两件事
keys144 真机崩溃日志（lead 提供）：
```
ESR : EC 0x25 IL 0x1 ISS 0x00000007   (data abort, translation fault level 3, read)
ELR = 0x0000C5B4E0FF0   FAR = 0x0000000000000008
X0  = 0x8000000000000E (EFI_NOT_FOUND)   X8 = 0   X20 = 0xC64F0000   X25 = 0xC7115000
ASSERT [ArmCpuDxe] CpuExceptionHandlerLib.c(438)
```
- `FAR=8` + `X8=0` 指向“以 NULL 为基址读 +8”。全镜像按页对齐基址反推（ELR 低 12 位应为故障指令 RVA 的低 12 位）后，没有任何模块在 RVA 0xFF0 有代码 ⇒ **ELR=0xC5B4E0FF0 很可能是照片 OCR 误读**，不能作为唯一定位依据。
- 在 UsbConfigDxe 内找到唯一完全吻合的站点：`0x53CC ldr x8,[x8,#0x8]`，其中 `0x53C8 ldr x8,[x8,#0x770]` = 全局 gIommuCtx（0x13770）。keys144 没有 HAL IOMMU 生产者 ⇒ gIommuCtx == NULL ⇒ 正是 `[0x0+8]`。
- 该拆卸路径 `0x5364/0x5394/0x53C4` 只有“初始化标志 0x13780 为 0 才跳过”的保护，缺 IOMMU 时标志被置 1 而 ctx 为 NULL（0x3FA8 加固只挡住初始化分支，挡不住拆卸分支）⇒ 需要真正的生产者 + 兜底 NULL 守卫。
- 已排除 UsbMassStorageDxe 0x2FF0（其 x8 = X25+X22，且 0x2FD8 预索引读已成功过）。
- `X4=0x9A` 与本故障无关，是上一次调用遗留的标量；`X0=EFI_NOT_FOUND` 也是遗留返回值（崩溃发生在 `ldr`，不是函数返回）。

### 改动（相对 keys144）
1. **恢复厂商 HAL IOMMU 生产者**（与 keys143 相同机制，未加 NO_HAL）：
   - `Include/DXE.inc:54` ← `# [keys70-hard] INF …/HALIOMMUDxe/HALIOMMUDxe.inf` 解注释；
   - `Include/APRIORI.inc:37` 解注释，且 provider（`VermeerDtbExtnDxe`，第 4 行）在其之前；
   - HALIOMMUDxe depex = 12 个 arch 协议全 AND，进 FV 即可 dispatch，无需改 depex；
   - DT 需求 `/soc/iort` 全部字段本树都有（keys142 已核对），无需改 DTS。
2. **UsbConfigDxe.patched.efi 拆卸路径 NULL 守卫**（文件偏移=RVA，4 个 u32，先验字节、幂等）：
```
0x53CC  F9400508 -> B4000128   ldr x8,[x8,#8]  -> cbz x8,0x53f0
0x53D0  D0000069 -> F9400508   adrp x9,0x13000 -> ldr x8,[x8,#8]
0x53D4  F90003E9 -> D0000069   str x9,[sp]     -> adrp x9,0x13000
0x53E0  F94003E9 -> D0000069   ldr x9,[sp]     -> adrp x9,0x13000
```
   反汇编结果：
```
53c4 adrp x8,0x13000 ; 53c8 ldr x8,[x8,#0x770] ; 53cc cbz x8,0x53f0
53d0 ldr x8,[x8,#8] ; 53d4 adrp x9,0x13000 ; 53d8 ldr x0,[x9,#0x778] ; 53dc blr x8
53e0 adrp x9,0x13000 ; 53e4 mov x8,xzr ; 53e8 str x8,[x9,#0x778] ; 53ec b 0x53f0
```
   即使 IOMMU 仍缺失，拆卸路径也只会跳过，不会 `[0x8]` 崩溃。
3. 保留 keys144 全部内容（ClockDxe 在 UsbConfigDxe 之前、keys143b 的 0x3FA8 `tbz w8,#0x1f` 加固、keys140 provider、AcpiTableDxe、UsbConfigDxe/UsbInitDxe/UsbMsdDxe 放置）。

### probe 实证（`_tools/b145_probe.log`）
- DXE.inc:54 HALIOMMU active；APRIORI `:4 provider / :37 HALIOMMU / :172 stub / :173 ClockDxe / :174 UsbConfigDxe / :175 UsbInitDxe / :176 UsbMsdDxe`；
- 构建期 UsbConfigDxe 0x3FA8=`0802f836`、0x53CC=`280100b4 080540f9 690000d0`；构建结束 restore trap 还原回 `0802f8b6` / `080540f9 690000d0 e90300f9`；
- patch_fat137 全部检查 OK。

### 产物与验证（verify145.sh / verify145b.sh / verify145c.sh）
- FD `_k70port_extract/qemu-fw/SILICIUM_UEFI-keys145.fd`：4,194,304 B，sha256=`b36597931d1871d9cf5454b470a222c80c3fa14d9e8cee8da2f954521f1aa247`
- 镜像 `K70-UEFI-build/Mu-vermeer-keys145.img`：1,796,096 B，sha256=`7660a804a85d82211cf096fe0f8056c9c1ba6ea835a1823bc4e1688dc9a24f6b`
- 交付副本 `K70-UEFI-build/K70-keys145-IOMMU-GUARD.img`：同 sha256
- Guid.xref：新增 `9A00771F-36D4-4DD5-8916-C48ED9B16B86 HALIOMMU`；ClockDxe、UsbConfigDxe、UsbInitDxe、UsbMsdDxe、UsbfnDwc3Dxe、UsbDeviceDxe、PmicDxe、VermeerDtbExtnDxe、VermeerLogDiskDxe、VermeerMenuDxe、AcpiTableDxe、VermeerPmicVerStubDxe 全在；UFSDxe 0。
- FVMAIN.inf 放置行：25 UsbfnDwc3Dxe、53 HALIOMMU、57 PmicDxe、69 ClockDxe、89 UsbMsdDxe、90 UsbConfigDxe、91 UsbInitDxe、96 VermeerDtbExtnDxe、101 AcpiTableDxe。
- FVMAIN.Fv：6,160,384 B；HALIOMMU GUID ×3、ClockDxe GUID ×3；UsbConfigDxe FFS 86,170 B（payload MZ@+0x64），`0x3FA8=0802f836`、`0x53CC=280100b4`、`0x53D0=080540f9`、`0x53D4=690000d0`、`0x53E0=690000d0`，且 pristine 的 `080540f9 690000d0 e90300f9` 在 payload 中不存在 ⇒ 补丁确实进 FV。
- DTB：FV 内 1 份，与 `xbl_ufs.dtb` 逐字节相同（57,217 B，sha256 `78c55f2e08136cbfa4f8c2fdfaae66ce67306f7a65395536c4568e92213a3f56`）。
- 构建结束 `UsbConfigDxe.patched.efi` 已还原为 pristine（0x3FA8=`0802f8b6`、0x53CC=`080540f9`）。

### 上机预期 / 下次真机看哪几行
1. 不应再出现 `ASSERT [ArmCpuDxe] CpuExceptionHandlerLib.c(438)` 的 `FAR=0x8` 崩溃；
2. HALIOMMU dispatch 后应出现 IOMMU 初始化相关日志，**不应**再打印 `Failed to open HAL IOMMU protocol Status = (0x%x)`（UsbConfigDxe 0x3FB0，str@0x10109）；
3. ClockDxe 在 UsbConfigDxe 之前（APRIORI 173<174、FVMAIN.inf 69<90），**`DisableUsbClocks: ClockProtocol unavailable` 应当消失**；若仍出现，说明 ClockDxe 没真正 InstallProtocol 或自身 dispatch 失败，需单独查 ClockDxe；
4. USB 继续往下走时，下一步重点看 UsbfnDwc3Dxe/UsbDeviceDxe 读取 `/soc/usb0/hs_phy_cfg`、`/soc/usb0/ss_phy_cfg` 的 `table` 属性日志（`HS: usb_shared_xbl_dtb_node_init …`、`usb_shared_process_phy_reg_dtb_list Failed`），hs 表在 DT 里是 `0xffffffff 0x00` 哨兵对，若 PHY 初始化被跳过属 vendor 语义，可能是下一个待解点；
5. 若出现新的 data abort，请同时给 ESR/ELR/FAR/X0..X8 与当时屏上最后 10 行日志；ELR 建议直接拍照或抄全 16 进制（本次 ELR 低 12 位为 0xFF0，与任何模块的代码段起始 0x1000 矛盾，疑似 OCR 误读）。

### 未改动项
vermeer.dsc、vermeer.fdf（仅 AcpiTableDxe 那一行由 keys142 解注释）、所有 _k70port_extract 下的构建脚本、provider 源码（VermeerDtbExtnDxe.c）、PmicDxeLa 及其它 QcomPkg 二进制、UsbConfigDxe 除上述 4 个 u32 外的字节。keys143b 的镜像/FD 未覆盖。
