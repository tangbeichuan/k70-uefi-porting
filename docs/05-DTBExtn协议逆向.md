# 05 · DTBExtn 协议逆向与应用

## 背景：厂商驱动要的不是 FDT，而是"DTBExtn 协议"

真机上很多高通 DXE 驱动（`UFSDxe`、`PmicDxeLa`、`HALIOMMU`、`DALTLMM`、`DisplayDxe` …）都不会自己去解析 FDT，
它们调用 **DTBExtn 协议** 取节点/属性。没有这个协议，它们会以 `EFI_NOT_FOUND` 退出，甚至把返回值当指针解引用而崩溃。

## 协议定义（逆向所得）

| 项 | 值 |
|---|---|
| 协议 GUID | `0389B776-625F-11EB-83BE-C741A913DE34` |
| 接口结构 | 0x108 字节，`word0 = version`（需 ≥ `0x10005`），其余为 0x20/0x30/0x40/0x58/0x68/0x70/0x88/0x90/0x98/0xa0/0xa8/0xc8 … 函数指针 |
| 生产者（原厂） | `EnvDxe.efi`：从 **DTB Extension HOB**（GUID `3A06E1E8-61F6-11EB-BBED-4B476E2FF6A7`）取地址，`CopyMem` 0x108 字节模板后 `InstallMultipleProtocolInterfaces` |
| HOB 数据 | 8 字节地址（XBL 发布），指向真实接口 |
| 已知消费者 | `UFSDxe`(`+0x30 GetNode`/`+0x58,+0xa8 GetProp`/`+0xc8 GetPropByte`)、`PmicDxeLa`、`HALIOMMU`、`DALTLMM`、`DisplayDxe`、`I2C/SPI`、`UsbConfig` 等 30+ 模块 |

## 我们踩过的坑（按时间）

1. **`XblProtocols.c` 的 `CompareGuid` 逻辑反了**：Mu 的 `CompareGuid` 相等返回 TRUE，而原代码 `if (CompareGuid(...) != 0) { GuidMatched = TRUE; continue; }`，
   导致拿到的地址是"最后一个不匹配的 GUID 字面量"→ `EnvDxe` 崩溃、`UFSDxe` 报 `Not Found`。
   - 修正后又发现：**修正本身让 Scheduler/DtbExtn HOB 变成非 0**，于是 `EnvDxe` 拿到假地址继续崩。
2. **真机根本没有设备树**：`[DTDUMP] cfgtable count=4 … no FDT table installed`，16 MiB FD 窗口扫 `d00dfeed` 命中 0。
3. **真正的 UEFI 设备树在 `xbl_config` 分区里**：`extracted/xbl_config_fdt_cb20.dtb`（13,893 B，含 `/soc/ufs0@1D80000`、`/sw/pmic`）、`xbl_config_fdt_10168.dtb`（57,171 B，含 `/soc/iort`、`/soc/usb*`、`/soc/pil`）。
   —— 内核口味 DTB（`vendor_boot` 里那棵 3.8 MB）**没有** `ufs0`，不能用。
4. **`MemoryMapLib` 缺 UFS 窗口**：`0x1D80000` 落在区段空洞里，`UFSDxe` 报 `Failed to map UFS_view_BASE`。补 `{"UFS", 0x1D80000, 0x20000}` 后消失（注意 PEI 静态表加项要谨慎，见 07）。
5. **`HALIOMMU` 要的是 ACPI IORT 表头字段**（`Signature/Revision/Checksum/OEMID`），DT 永远给不出 → 它的 `ParseIORTD` 必挂，属死路，直接用"强制 no-IOMMU 回退"绕过。

## 我们的 provider 实现要点

`drivers/VermeerDtbExtnDxe/`：

- 树来源：FV 内 `FILE FREEFORM = 7E5B1C3A-9D24-4E77-9C1B-2A6D5F8E4C31`（`vermeerPkg/FdtBlob/xbl_ufs.dtb`，由 `xbl_config_fdt_10168.dtb` 派生，含补出来的 `pre-psi` 节点）；
- 用 `GetSectionFromAnyFv` 取 RAW，**不依赖块设备**；
- 自带迷你 FDT 解析（`FdtFindChild`/`FdtPathOffset`/`FdtGetProp`），
  **注意 `FDT_PROP` 布局**：`token(4) + len(4) + nameoff(4) + data`，`P += 12 + align4(len)`；
- 句柄用"blob 内指针"返回（`mBlob + offset`），属性名/出参/大小做启发式识别（`SlotGetGeneric`），
  **同一槽位的语义按调用参数反推**（`+0x28`=子节点计数、`+0x68`=子节点大小、`+0x70`=子节点名、`+0x90`=属性大小、`0xa0`/`0x88`=按名取属性…）；
- 属性不存在时**返回 `EFI_NOT_FOUND` 而不是 0 长度成功**（否则厂商拿到一坨零继续跑 → 别的崩溃）。

## 验证方法（不刷机也能自检）

- `[DTBEXTN] selftest ufs0: reg=0x1d80000 (want 0x1d80000) … s=Success/Success/Success`
- `[DTBEXTN] selftest vadc: children=4 first="vadc_ch_cfg" second="vadc-avg-ch"`（与离线 Python 复算逐字节一致）
- 离线复算脚本：`scripts/fdt_verify.py`（同一套算法，用 `xbl_ufs.dtb` 跑出 `/soc`→0x90、`/soc/ufs0`→0x27C 等）