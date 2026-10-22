# keys147d — USB device-stack probe (embedded in VermeerLogDiskDxe)

数据截至 2026-10-22 02:32 (+08:00)。基线 = lead 的 keys147c（VBUS 覆盖内嵌在
VermeerDtbExtnDxe，无独立 VbusDxe 模块）。keys147d 只加一件事：**在已有的
VermeerLogDiskDxe 里内嵌 USB 设备栈诊断**，不新增任何 FV 模块。

## 产物

| 文件 | 大小 | sha256 |
|---|---|---|
| `K70-UEFI-build/Mu-vermeer-keys147d.img` | 1,796,096 B | `22d1d32a9a75b34ca30f9f0e2f96415fa1eaa0f19806cea9314204f25ce35f2b` |
| `K70-UEFI-build/K70-keys147d-USBDIAG.img`（副本） | 同上 | 同上 |
| `_k70port_extract/qemu-fw/SILICIUM_UEFI-keys147d.fd` | 4,194,304 B | `0fa26f07427035b25f1bf1f6dde21f3c955520b7f9d3cf7db5759c56144c5815` |

回退基线 keys147c：img `e345e0c7c00d93290d41e5886ccb5322e0a16ba78842eeb477581b63fef92a64`，
FD `d98ce6e8172c258d39e00f7caa478ffd739d6b37907ad377cc2511faa7bda459`。

## 相对 keys147c 的改动（唯一）

`VermeerLogDiskDxe.c`（**构建读取的是 `_tools/VermeerLogDiskDxe.c`**，由
`patch_copy123.py` 拷进 pkg；`port-drivers/` 那份是副本，两份已同步同一内容）
新增 `VERMEER_USB_DIAG` 块：

1. `UsbDiagTimerCallback`（`EVT_TIMER` + `TPL_CALLBACK`，相对 2 s 触发，落在 BDS
   事件循环里，即所有 APRIORI 驱动 dispatch + ConnectController 之后）打印：
   - `[USBDIAG] ---- USB device-stack probe ----`
   - `LocateProtocol(QcomUsbConfig)=%r iface=%p`
   - `iface+0x88=%08x iface+0x8c=%08x`（UsbfnDwc3.Supported 的判据：<=3 且 ==4）
   - `DWC3 GCTL=%08x DCTL=%08x DSTS=%08x`（只读快照；DCTL bit0=RUN_STOP，
     DSTS bit31=DEVCTRLHLT，GCTL bit[1:0]=PrtCapDir）
   - `LocateProtocol(UsbFnIo)=%r iface=%p  <-- controller STARTED if Success`
   - `QcomUsbConfig handles=%d status=%r`
   - 若 UsbFnIo 缺失：对每个 QcomUsbConfig 句柄 `ConnectController(...,FALSE)` 并打印 Status，
     随后再查一次 UsbFnIo + DCTL/DSTS
   - `[USBDIAG] ---- probe end ----`
2. `UsbFnIoNotify`（`EVT_NOTIFY_SIGNAL` + `RegisterProtocolNotify`）打印
   `[USBDIAG] UsbFnIo notify: status=%r iface=%p  <-- controller STARTED`：
   只要 UsbfnDwc3Dxe 的 Start() 成功（它在这里 InstallMultipleProtocolInterfaces），
   无论发生在何时都会有一行。

## 构建后离线验证（全部通过）

- FD 内 UsbConfigDxe（`cf146d.py` 从 FD 解 LZMA→FVMAIN→PE 逐字节核对）：
  `0x3FA8 = 0x14000002`（keys146 的 `b 0x3fb0` 强制 no-IOMMU 回退）、
  `0x53CC = 0x280100b4`（keys145 反初始化 NULL 守卫）、`0x53D4 = 0xd0000069`。
- FVMAIN.Fv 内：HALIOMMUDxe **在**、ClockDxe **在**、AcpiTableDxe **在**、
  UsbConfigDxe/UsbInitDxe/UsbMsdDxe/UsbfnDwc3Dxe/UsbDeviceDxe 均在；UFSDxe **不在**。
- `USBDIAG` 字符串出现在 FVMAIN.Fv 中 **13** 次；LogDisk EFI 20,480 → **22,528 B**，
  其 payload 在 FV 中 1 份。
- `[VBUS] before:` / `[VBUS] after :` 字符串在 FV 中出现 **1** 次（keys147c 的 VBUS 覆盖仍在）。
- 内嵌 DTB 1 份，与 `xbl_ufs.dtb` 逐字节相同（57,217 B，
  sha256 `78c55f2e08136cbfa4f8c2fdfaae66ce67306f7a65395536c4568e92213a3f56`）。
- 独立 `VermeerUsbVbusDxe` **不在 FV**（FVMAIN.Fv 中 `4A8E2C71` 计数 0）。
  注：pkg `vermeer.dsc:133` 仍留一行 147b 遗留的 `VermeerUsbVbusDxe.inf` 组件行，
  它只参与编译、不进任何 FDF include，故不影响 FV/引导；本版未清理以保持与 147c 一致。

## 上机看哪几行（判据表）

`[USBDIAG]` 行在 dispatch 结束后约 2 s 出现（BDS 刚开始跑事件循环时）。若屏幕已被
menu 重画遮住，**重启后盯 menu 出现前 1–3 秒**拍屏。

| 屏幕输出 | 含义 | 下一步 |
|---|---|---|
| `UsbFnIo notify: status=Success` 或 probe 里 `LocateProtocol(UsbFnIo)=Success` | **控制器已 start**（UsbfnDwc3 Start 成功、UsbFnIo 已装） | 问题在设备类/描述符层：直接上 CDC ACM（UsbDeviceDxe 之后） |
| `LocateProtocol(QcomUsbConfig)=Success` 且 `iface+0x88`/`+0x8c` = `0`/`4` | QcomUsbConfig 协议发布正确，模板字段符合 UsbfnDwc3.Supported 判据 | 说明这次不是 provider/IOMMU 的锅 |
| `UsbFnIo=EFI_NOT_FOUND`，`ConnectController` 返回 `Success`/`AlreadyStarted` 后再查仍 NOT_FOUND | 驱动绑定成功但 Start 失败（缺时钟/PHY/VBUS 或内部错误） | 看 DCTL/DSTS 与 VBUS 寄存器；转向 CDC ACM 时仍需先解决 start |
| `ConnectController` 返回 `EFI_NOT_FOUND` | 没有驱动认领该句柄（Supported 全 reject），通常是 `iface+0x88/+0x8c` 不符或 UsbfnDwc3 不在 DB | 查 `iface+0x88/+0x8c` 实际值 |
| `ConnectController` 返回 `EFI_ALREADY_STARTED` 且 UsbFnIo 仍 NOT_FOUND | 已绑定但 Start 回滚（UEFI 断开后重连失败） | 需要 UsbfnDwc3 Start 内部日志（下一步可加） |
| `GCTL` PrtCapDir=1（bit[1:0]=01）、`DCTL` bit0=0、`DSTS` bit31=0 | DWC3 已置于 device 模式且未 halt = 控制器确实在跑 | 若 host 仍无设备，问题在 D+ 上拉/VBUS 或描述符 |
| `DCTL` bit0=1 或 `DSTS` bit31=1 | 控制器 halt/未运行 | 对应 VBUS/DCTL.RUN_STOP 时序（lead 的"VBUS→DCTL.RUN_STOP=1→等 DEVCTRLHLT 清"） |

## keys147 四问的回答（静态 + 这次可验证）

1. **UsbfnDwc3Dxe 上线条件**：它是 DriverBinding；`Supported` 用
   `OpenProtocol(ControllerHandle, E722B03F)` 取 QcomUsbConfig 接口，要求
   `iface+0x88 <= 3 && iface+0x8c == 4`；`Start` 再 OpenProtocol 一次，取
   `ctx+0xa8 = QcomUsbConfig`，读 `[iface+0x88]` 存 `ctx+0x17c`，依次调
   `[iface+0x28]`、`[iface+0x8]`，然后
   `InstallMultipleProtocolInterfaces(&handle, &gEfiUsbFunctionIoProtocolGuid, ctx+0x8)`
   ——**这就是"控制器 start"的唯一硬标志**。PHY 表的 usb_shared 代码在
   UsbDeviceDxe 里（字符串 `usb_shared_xbl_dtb_node_init ...`、`/soc/usb0/hs_phy_cfg`），
   它在 UsbFnIo 之后才跑，所以屏上没有 PHY 输出 = 它还没被调用（不是静默失败）。
2. **UsbDeviceDxe 是否需要 ConnectS 事件 + UsbConfigProtocol**：它先
   `LocateProtocol(32D2963A UsbFnIo)`（惰性缓存 0xA450），再
   `InstallMultipleProtocolInterfaces(&handle, &gEfiUsbDeviceProtocolGuid, iface=0xA0F8)`；
   UsbConfigProtocol（E722B03F）由 UsbConfigDxe 在 **IOMMU 初始化之前**（0x3D48 < 0x3F68）
   安装，我们的 no-IOMMU 回退不跳过它。本次 probe 的 `iface+0x88/+0x8c` 行可直接确认。
3. **UsbMsdDxe 与 BlockIo 顺序**：Msd 先 `LocateProtocol(UsbFnIo)`，再按**分区类型
   GUID**（UFS LU0..7、eMMC boot/user/GPP、SD removable、PartitionType/Record）
   扫描本机 BlockIo 并把匹配的盘导出给 host；我们的 1 MB RAM FAT 卷没有分区表、
   没有这些 GUID ⇒ **永远选不中**，LogDisk 放在 Msd 之前也没用。U 盘路线判死
   （与 lead 结论一致），后续走 CDC ACM。
4. **需要补的 DT 节点**：不需要。`/soc/usb0`（DTS 第 1567 行，`compatible="qcom,usb"`）
   已有 `hs_phy_cfg.table`（4 组 `0xffffffff 0x00` 哨兵）与 `ss_phy_cfg.table`
   （真实 QUSB2/SS 寄存器对）；vendor 不自带 qcom,dwc3/snps,dwc3 解析，DWC3 基址
   0x0A600000 是写死的，VBUS 走 QSCRATCH(0x0A6F8800) 而非 DT。

## 风险与回退

- 本版 FVMAIN.Fv 6,160,384 → 6,164,480 B（LogDisk FFS 变大 2 KB，其后模块整体后移）。
  keys147b 的挂死是"新增模块 + APRIORI 新句柄"，本次只是既有模块增大 payload，
  keys140–146 多次同类增大均正常；若真机在 `MMU: enabled` 前挂，回退 keys147c。
- 未做 SMMU 映射（keys146 起就不做），no-IOMMU 回退标记行 `Failed to open HAL IOMMU
  protocol Status = (0x0)` 应仍然只出现一次。
- 只读 DWC3 寄存器（GCTL/DCTL/DSTS 各一次）；若该 MMIO 区未映射会同步异常——理论上
  必已映射（vendor UsbConfigDxe 自己读写 0xA600000/C110/C700/C704），但这是本版唯一
  新增的 MMIO 风险点，若崩在 `[USBDIAG]` 第一行之后即定位到它。
