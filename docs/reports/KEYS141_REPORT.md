# keys141 报告：UsbConfigDxe 进 FV + 派发顺序 + depex 需求

时间：2026-10-22 01:3x（Asia/Shanghai）

## 1. 构建产物（已交付）

| 产物 | 路径 | sha256 | 大小 |
|---|---|---|---|
| FD | `/root/k70/uefi/Build/vermeerPkg/DEBUG_CLANGPDB/FV/SILICIUM_UEFI-keys141.fd`（WSL）/ `_k70port_extract/qemu-fw/SILICIUM_UEFI-keys141.fd` | `84e68ffbfe67e204585b76e065474319e347549f2e3bff3366b1037b351cb193` | 4,194,304 B |
| 镜像 | `D:\本地项目-01\K70-UEFI-build\Mu-vermeer-keys141.img` | `a66b1a6385dcc544b03af6e6593e117f41b6c1302a23e2be4c9bd77cccc59a9c` | 1,744,896 B |
| 交付副本 | `D:\本地项目-01\K70-UEFI-build\K70-keys141-USB-CONFIG.img` | 同上 `a66b1a63…a9c` | 同上 |

构建日志：`_tools/b141.log`，尾 `SECTION - Summary` / `PROGRESS - Success`。

## 2. 根因修复（UsbConfigDxe 为何没进 FV）

- `Include/APRIORI.inc` 第 1~205 行是 `APRIORI DXE { ... }` **派发顺序块**，不是 FV 内容清单；`}` 之后 206~209 的 4 行才是 FV 放置行。
- FV 放置的权威清单是 `Include/DXE.inc`。keys140 血缘的 DROP 列表里含 `"usbconfig"`，把 `DXE.inc:185` 的 UsbConfigDxe 行注释成 `# [keys140-drop]   INF .../UsbConfigDxe/UsbConfigDxe.inf`；而 `patch_usb130.py` 只解注释 **APRIORI.inc**，不修 DXE.inc → 有派发顺序、无 FV 实体。
- 新增 `_tools/patch_usb141.py`（挂到 patch 链 `patch_usb130.py` 之后、`patch_fat137.py` 之前）：
  1. 把 DXE.inc 里 UsbConfigDxe 的 `# [keys140-drop] …` 行解注释为 `  INF Binaries/vermeer/QcomPkg/Drivers/UsbConfigDxe/UsbConfigDxe.inf`；
  2. 在 APRIORI.inc 派发块内保证顺序 **VermeerPmicVerStubDxe(173) → UsbConfigDxe(174) → UsbInitDxe(175) → UsbMsdDxe(176)**；
  3. 只删 3 条 INF 行本身、保留 `!if` gate 对（第一版按 gate 块删会误删 stub 行，已修）。
- 构建血缘：`_tools/run141.sh` → `_k70port_extract/wsl/build_keys141.sh` / `run_keys141.sh`（sed 140→141；**不含** patch_nopmic138.py，真 PMIC 保留）。
- keys140 的改动全部保留并已验证。

## 3. 验证结果（Guid.xref + FVMAIN.inf）

Guid.xref 五行**齐全**：
```
CD823A4D-7DEC-4531-AE5D-4134FA4127B8 UsbConfigDxe
0A134F0E-075E-40B3-9C63-3B3906804663 UsbInitDxe
5AF77F10-90DF-4E7E-8325-A17EC09D5443 UsbMsdDxe
94F8A6A7-DC34-4101-88C1-99179CCEAE83 UsbfnDwc3Dxe
3F6C1D92-85B4-4E27-9C63-1A8F5D2E7B04 VermeerPmicVerStubDxe
```
keys140 保留项也在：`5776232E-… PmicDxe`、`5B21E7C4-… VermeerDtbExtnDxe`、`9C5E7A31-… VermeerLogDiskDxe`、`4F7A1C2E-… VermeerMenuDxe`。
FVMAIN.inf：25 UsbfnDwc3Dxe、87 UsbMsdDxe、**88 UsbConfigDxe**、89 UsbInitDxe。
FVMAIN.Fv 内 FFS GUID：`CD823A4D`×3、`EB97088E`×3、`3F6C1D92`×1、`4684800A`×3。
DTB FILE FREEFORM 仍与 `xbl_ufs.dtb` 逐字节相同（57217 B，sha256 `78c55f2e…3f56`）；provider 断言串均在。UFSDxe 计数 0。

## 4. depex 需求（关键结论）

`UsbConfigDxe.depex`（90 B）解码：5 个协议**全部 AND**：

| # | GUID | 身份 | 生产者 | 本镜像内？ |
|---|---|---|---|---|
| 1 | `B0760469-970C-487A-A4B5-28DB7B45CEF1` | gEfiChipInfoProtocolGuid | ChipInfoDxe | ✅ 在 FV |
| 2 | `FA5F306B-F47D-4AC4-A47D-882F8204EC30` | SPMI 协议 | SPMIDxe | ✅ 在 FV |
| 3 | `F4E5C7D0-D239-47CB-AACD-7F66EF763238` | gEfiSMEMProtocolGuid | SmemDxe | ✅ 在 FV |
| 4 | `157A5C45-21B2-43C5-BA7C-822FEE5FE599` | gEfiPlatformInfoProtocolGuid | PlatformInfoDxe | ✅ 在 FV |
| 5 | `EB97088E-CFDF-49C6-BE4B-D906A5B20E86` | **gEfiAcpiSdtProtocolGuid**（EFI_ACPI_SDT_PROTOCOL） | MdeModulePkg `Universal/Acpi/AcpiTableDxe/AcpiTableDxe.inf` | ❌ **无生产者** |

- 第 5 项无生产者的原因：`vermeer.fdf:133-136` 的 ACPI 块整块被注释（`#INF ...AcpiTableDxe.inf`、`#INF ...AcpiPlatformDxe.inf`、`#INF RuleOverride = ACPITABLE vermeer/AcpiTables.inf`），`vermeer.dsc:160-162` 的 AcpiTables.inf 也注释 → 本镜像没有任何 ACPI 驱动。AcpiTableDxe 的二进制是编译出来的（`Build/.../AARCH64/AcpiTableDxe.efi` 42,496 B，来自 `SiliciumPkg.dsc.inc:496`），但 FDF 未放置。
- 旁证：原厂 FV dump（`_k70port_extract/fv_dump/fv_191fd0.bin`）里 `9622E42C`（AcpiTableDxe FILE GUID）计数也是 **0**，SDT 协议 GUID 只有 2 处（消费者）。
- **结论：keys141 里 UsbConfigDxe 已经进 FV，但 depex 第 5 项永远不满足，DXE 不会 dispatch 它**（不会崩，只是挂起）。因此 keys141 单独不会带来 USB 配置功能。

### 4.1 连带影响：UsbConfigDxe 是 E722B03F 的唯一生产者

- `UsbConfigDxe.patched.efi` 在 `0x3d48` 用 `gBS->InstallMultipleProtocolInterfaces(gBS+0x148)` 安装 `E722B03F-B250-42CE-8EBD-5BD51812D037`（GUID 常量在 .data `0x130c8`，接口结构在 `0x13470`）。该 GUID 在 UsbConfigDxe/.data 只出现 1 次 = 生产。
- `UsbInitDxe.depex` 只依赖 `E722B03F-B250-42CE-8EBD-5BD51812D037`；`UsbInitDxe.efi` 在 0x17d0 用 LocateProtocol 找它（GUID 常量 @0x6078）。
- `UsbfnDwc3Dxe.efi` 用 gBS->OpenProtocol(+0x118)/CloseProtocol(+0x120) 打开它（GUID 常量 @0x16098）= 消费者。
- ⇒ 缺 SDT 协议 → UsbConfigDxe 不 dispatch → E722B03F 不存在 → **UsbInitDxe 也不 dispatch** → USB device-mode 链路（UsbfnDwc3Dxe/USbDeviceDxe/UsbMsdDxe/LogDisk 暴露）不完整。这很可能就是 PC 端看不到盘的直接原因。

## 5. stub 需求（若由 lead 在镜像里补）

需要装 `gEfiAcpiSdtProtocolGuid = EB97088E-CFDF-49C6-BE4B-D906A5B20E86`，接口布局按本树 `Mu_Basecore/MdePkg/Include/Protocol/AcpiSystemDescriptionTable.h`（**带 AcpiVersion 的新版**，总 0x50 字节）：

```
+0x00 UINT32 AcpiVersion;        // 4 字节 + 4 字节对齐填充
+0x08 GetAcpiTable(Index, **Table, *Version, *TableKey)
+0x10 RegisterNotify(BOOLEAN Register, FN Notification)     ← UsbConfigDxe 调用
+0x18 Open(Buffer, *Handle)                                  ← 调用
+0x20 OpenSdt(TableKey, *Handle)
+0x28 Close(Handle)                                          ← 调用
+0x30 GetChild(Parent, *Handle)
+0x38 GetOption(Handle, Index, *DataType, **Data, *DataSize) ← 调用
+0x40 SetOption(Handle, Index, Data, DataSize)               ← 调用
+0x48 FindPath(HandleIn, AcpiPath, *HandleOut)               ← 调用
```
UsbConfigDxe 实际调用点（`UsbConfigDxe.patched.efi`，实测）：
- `0x71d4: ldr x8,[gSdt,#0x10]` + `(w0=1, x1=0x7200)` → RegisterNotify(TRUE, cb)；
- `0x6ea4: [+0x18]` Open(buf+0x24, &handle)；`0x6efc: [+0x48]` FindPath(handle,"QUFN",…)；`0x6f5c/0x702c: [+0x38]` GetOption；`0x709c: [+0x40]` SetOption；`0x712c: [+0x28]` Close。
- gSdt 全局变量在 `0x137c8`（`.data`），LocateProtocol 在 0x7178；失败日志串 `0x102d0 "[UsbConfig]Failed to Locate SDT protocol"`、`0x10c7c "[UsbConfig] Error gAcpiSdt->FindPath, Status"`。
- 安全做法：`RegisterNotify`/`Close` 返回 EFI_SUCCESS，其余方法返回 EFI_NOT_FOUND（或 EFI_UNSUPPORTED），这样 UsbConfigDxe 的 DSDT 补丁路径优雅失败、不 deref 空出参。注意 `Open` 成功时必须给非空 handle，否则后续会空指针。

替代（更省事、风险也低）：直接在 `vermeer.fdf:134` 解注释 `INF MdeModulePkg/Universal/Acpi/AcpiTableDxe/AcpiTableDxe.inf`（该模块已在 dsc 组件里、可编译），得到**真实** SDT 协议；是否连带解注释 135/136（AcpiPlatformDxe/AcpiTables）视需要。这样不用改 depex 也不用写 stub。

## 6. 其它

- UsbInitDxe depex 仅 `E722B03F-B250-42CE-8EBD-5BD51812D037`（源码树无名字；UsbConfigDxe 内含该 GUID，疑为 UsbConfig 协议，故顺序 config→init 必须保留，已保证）。
- `4684800A-2755-4EDC-B443-7F8CEB3239D3` = gQcomPmicVersionProtocolGuid（PmicDxe/UsbPwrCtrlDxe/我们的 VermeerPmicVerStubDxe 生产），**不在** UsbConfigDxe depex 里，但 UsbConfigDxe 内含 GUID（运行时 Locate）。
- 离线脚本：`_tools/usb141_*.py|sh`、`pmic_50~52*.sh`、`verify141.sh`。
