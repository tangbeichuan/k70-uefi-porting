#!/bin/bash
set -e
R=/mnt/d/本地项目-01/_tools/KEYS143_REPORT.md
cat >> "$R" <<'EOF'

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
EOF
echo "appended; lines:"; wc -l "$R"
