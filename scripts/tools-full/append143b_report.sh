#!/bin/bash
set -e
R=/mnt/d/本地项目-01/_tools/KEYS143_REPORT.md
cat >> "$R" <<'EOF'

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
EOF
echo "appended; total lines:"; wc -l "$R"
