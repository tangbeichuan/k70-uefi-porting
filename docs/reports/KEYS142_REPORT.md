# keys142 — 启用真实 AcpiTableDxe（gEfiAcpiSdtProtocolGuid 生产者）

日期：2026-10-22  ~01:26  |  血缘：keys140 → keys141 → keys142

## 1. 改动（仅一处，脚本 `_tools/patch_acpi142.py`）

| 文件 | 改动 | 说明 |
|---|---|---|
| `vermeer.fdf` | 解注释 `INF MdeModulePkg/Universal/Acpi/AcpiTableDxe/AcpiTableDxe.inf` | 原始文件第 **134** 行；构建时因前序 patch 已删掉上方 2 行，实际落在第 **132** 行 |
| `vermeer.fdf` | `AcpiPlatformDxe` 与 `RuleOverride = ACPITABLE vermeer/AcpiTables.inf` **保持注释** | 按 Lead 要求，只要 SDT 生产者，不向 ACPI 表里塞我们的表 |
| `vermeer.dsc` | 不动 | `Silicon/Silicium/SiliciumPkg/SiliciumPkg.dsc.inc:496` 已包含 AcpiTableDxe 组件，EFI 每次都编译（42,496 B） |

幂等：已解注释则打印 "already active" 且不改文件；若发现 AcpiPlatformDxe/AcpiTables 被误解注释则 FATAL 退出。

## 2. 关键原理

- UsbConfigDxe 的 depex 是 5 个协议 AND：ChipInfo / SPMI / SMEM / PlatformInfo / **gEfiAcpiSdtProtocolGuid (EB97088E-CFDF-49C6-BE4B-D906A5B20E86)**。
- 前 4 个生产者（ChipInfoDxe / SPMIDxe / SmemDxe / PlatformInfoDxe）都在 FV 里；第 5 个唯一生产者是 `MdeModulePkg/Universal/Acpi/AcpiTableDxe`，而 vermeer.fdf 的 ACPI 块整块被注释 → 永远不满足。
- UsbConfigDxe 又是 **E722B03F-B250-42CE-8EBD-5BD51812D037 的唯一生产者**（0x3d48 InstallMultipleProtocolInterfaces，GUID@0x130c8，接口@0x13470/0x13488），UsbInitDxe 的 depex 只依赖它 → 缺 SDT 时 UsbInitDxe 也不会 dispatch。
- AcpiTableDxe.inf 的 `[Depex]` = `TRUE`，进 FV 即可 dispatch；其 EntryPoint 安装 `gEfiAcpiTableProtocolGuid (FFE06BDD-6107-46A6-7BB2-5A9C7EC5275C)` 与 `gEfiAcpiSdtProtocolGuid (EB97088E…)`。

## 3. 产物

| 产物 | 路径 | sha256 | 大小 |
|---|---|---|---|
| FD | `_k70port_extract/qemu-fw/SILICIUM_UEFI-keys142.fd` | `39e745df1eeeeb0cabece559b76ad03e78aa707ac17b02a495927d69df428891` | 4,194,304 B |
| 镜像 | `K70-UEFI-build/Mu-vermeer-keys142.img`（= `-fat.img`） | `7c2eccad35f764a74495ba3e56201d92f0fbe21f4abc415ec0a7c6ecd27d834b` | 1,753,088 B |
| 交付副本 | `K70-UEFI-build/K70-keys142-ACPI-SDT.img` | 同上 | 1,753,088 B |

（`-marker.img` 同 sha；`-v4.img` = ec9585ed…）

## 4. 验证

- `Guid.xref` 出现 **`9622E42C-8E38-4a08-9E8F-54F784652F6B AcpiTableDxe`** ✓
- keys141 五行保持：UsbConfigDxe(CD823A4D) / UsbInitDxe(0A134F0E) / UsbMsdDxe(5AF77F10) / UsbfnDwc3Dxe(94F8A6A7) / VermeerPmicVerStubDxe(3F6C1D92) ✓
- keys140 保留：PmicDxe(5776232E) / VermeerDtbExtnDxe(5B21E7C4) / VermeerLogDiskDxe(9C5E7A31) / VermeerMenuDxe(4F7A1C2E) ✓
- `FVMAIN.inf` 中 AcpiTableDxe 放置行 = **第 99 行**；UsbfnDwc3Dxe=25、UsbMsdDxe=87、UsbConfigDxe=88、UsbInitDxe=89。
- FVMAIN.Fv（5,767,168 B）内：AcpiTableDxe FFS GUID ×1 @0x3caba0；EB97088E ×4（新增 @0x3d4bec = AcpiTableDxe .data）；FFE06BDD ×3（新增 @0x3d4bfc）。
- DTB FILE FREEFORM 仍与 `xbl_ufs.dtb` 逐字节相同（57,217 B，sha `78c55f2e08136cbfa4f8c2fdfaae66ce67306f7a65395536c4568e92213a3f56`，FV 中 1 份）；provider 串 `vermeer dtb-extn provider` / `+0x28 count(` / `+0x68 sizes(` / `+0x70 names(` 各 1，`selftest vadc` 2。
- FVMAIN.inf 中 UFSDxe 计数 0。
- 构建日志尾 `PROGRESS - Success`（`_tools/b142.log`）。

## 5. 上机预期

- AcpiTableDxe dispatch（depex TRUE）→ SDT/ACPI Table 协议安装 → UsbConfigDxe depex 满足 → dispatch → 安装 E722B03F → UsbInitDxe dispatch → USB device-mode 链路（UsbfnDwc3Dxe/UsbDeviceDxe/UsbMsdDxe/LogDisk）齐备。
- 若 AcpiTableDxe 找不到 ACPI 表存储（FV 里没有 ACPITABLE 段），按 EDK2 实现它仍会成功安装两个协议并返回，不致命。
- 可能的残留风险：UsbConfigDxe 在 DSDT 通知回调里用 FindPath("QUFN")/GetOption/SetOption 改表；本镜像 DSDT 由谁提供未定，若 GetAcpiTable 无表则回调不会触发，属安全路径。

## 6. 未改动 / 未验证

- 未改 depex、未加 stub、未开 AcpiPlatformDxe/AcpiTables、未动 DSC。
- 未上机验证（本次仅构建+离线校验）。
