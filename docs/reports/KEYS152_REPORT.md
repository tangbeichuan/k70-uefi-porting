# keys152 / keys153 交付报告（Menu 最小化 bisect + keys149 回归基线）

生成时间：2026-10-22 10:05（Asia/Shanghai）
基线：keys149（lead 真机可启动）与 keys150（lead 真机卡 `MMU: enabled`）的 FD 均已逐模块比对。

---

## 1. 交付物（可直接刷）

| 包 | 文件 | 大小 | sha256 | 用途 |
|---|---|---|---|---|
| **keys153** | `K70-UEFI-build/Mu-vermeer-keys153.img` | 1,794,048 | `d8784724add3a60007cbd887eb719455b1144172667c7feaec224d8ade19f744` | **回归基线**：keys149 的 FD 原样重打包 |
| | `K70-UEFI-build/K70-keys153-REPACK-BASELINE.img` | 1,794,048 | 同上 | 交付副本 |
| | `_k70port_extract/qemu-fw/SILICIUM_UEFI-keys153.fd` | 4,194,304 | `fdc529e91f69f0f1c5b5b0d8667933aafef545f02a098e778f14ecdfb2d5693b` | 与 keys149 FD **逐字节相同** |
| **keys152** | `K70-UEFI-build/Mu-vermeer-keys152.img` | 1,794,048 | `0f0be4f2f3148192710893206a78ab0984dda1c2641db5c4f71c486bc9fff942` | Menu 最小化（只读诊断） |
| | `K70-UEFI-build/K70-keys152-MINIMAL-MENU.img` | 1,794,048 | 同上 | 交付副本 |
| | `_k70port_extract/qemu-fw/SILICIUM_UEFI-keys152.fd` | 4,194,304 | `1cc799f1c04b06d140b2316636f16052ec6cd27010184e3aaf68f480e72dcbfa` | FD |

> 注意：早前有一版 keys152（img `22abb01f…`）是**坏包**（构建时 MemoryMapLib 的 USB 行处于被删状态，PEI 与 keys149 不同），已被本次 `0f0be4f2…` 覆盖，请勿使用旧 sha。

---

## 2. keys153：keys149 原样重打包（零风险回归）

- `SILICIUM_UEFI-keys153.fd` 与 `SILICIUM_UEFI-keys149.fd` **逐字节相同**（sha 均为 `fdc529e9…`）。
- `Mu-vermeer-keys153.img` 与 `Mu-vermeer-keys149.img` **逐字节相同**（sha 均为 `d8784724…`）。
- 重打包脚本同样输入（FD + `Resources/DTBs/vermeer.dtb` 808,716 B / sha `71da2503…` + 192 B BootShim）⇒ 输出确定，`cmp` 打印 `IDENTICAL`。
- 用途：手机从 `MMU: enabled` 卡死恢复后，先刷 keys153 验证"刷机链 + 引导环境"正常，再做 bisect。

---

## 3. keys152：相对 keys149 的差异（只有 Menu 一个模块）

FD→FFS→LZMA→FVMAIN 逐模块比对（`_tools/k151_cmp.py`，90 个模块）：

| 项 | keys149 | keys152 |
|---|---|---|
| 模块数 | 90 | 90（0 增删） |
| **变化模块** | — | **只有 `VermeerMenuDxe`**：19,030 B / `0f79eaaf…` → 20,054 B / `fd27b1f3…` |
| SEC/PEI FFS body sha | `cfcfca5efb6b80fe` | **`cfcfca5efb6b80fe`（相同）** |
| inner FV 长度 | 0x5df000 | 0x5df000（相同） |
| 其它 89 个模块 | — | 与 keys149 **逐字节相同** |

⇒ **PEI 一个字节都没动**；keys150 里被移动/变化的其它 45 个模块是当时全量重编的缓存差异，本次已回到 keys149 的字节（touch `MemoryMapLib.c` 触发正确的 PEI 重建，restore 的 USB 行已确认存在，`rows=43`）。

### Menu 模块改了什么（`port-drivers/VermeerMenuDxe/VermeerMenuDxe.c`，`patch_usb152.py` 生成）

1. `ForceLoadSimpleFb` 改为打印桩：`[UI152] SimpleFb load disabled (keys152)`，**不再 LoadImage/StartImage**（保留 `mFbLoadTried` 防呆）。
2. `Usb150LateDiag`（写 PHYCFG 清位 / GCTL.PRTCAPDIR=device / DCTL.RUN_STOP / 轮询 DSTS bit22 / Stall 重试 / QSCRATCH VBUS 覆盖）**整块删除**，换成只读 `Usb152Diag`：
   - `Usb150Dump(L"pre ")` + `Usb150Dump(L"post")`（**只读** GSNPSID/GCTL/GSTS/PHYCFG/PIPECTL/DCFG/DCTL/DSTS，并解码 prtcap/run/hlt22/spd/lnk/susphy/enblslpm/phyrst/gsts_b0）；
   - `[USB152] vbus readonly: HS=%08x SS=%08x GCC_GDSCR=%08x`（只读 0x0A6F8800+0x10/+0x30、0x0010F004）。
3. `Usb150Wr` 写函数**已删除**（源码 `grep 'Usb150Wr ('` = 0）。
4. entry 尾部：`[MENU152] minimal menu: read-only diag, no writes, returning to BDS` → diag → `[MENU152] diag done - no CpuDeadLoop, returning` → `return EFI_SUCCESS`（**无 CpuDeadLoop**；`mGuiDisabled152` 分支保留 RunMenu 引用仅为防止 LTO 优化掉 UI 代码）。
5. 全源码已无任何对 DWC3/GCC/QSCRATCH 的写操作（`PRTCAPDIR/RUN_STOP/QSCRATCH` 只剩注释与只读解码；`MmioWrite` = 0）。

构建产物 Menu EFI：19,968 B，UTF-16 串 `MENU152` ×2、`USB152` ×1、`diag done` ×1、`CpuDeadLoop` ×1（仅出现在 `"diag done - no CpuDeadLoop, returning"` 这句提示文本里，不是调用）。

---

## 4. 启动容器结构核对（keys152）

`ANDROID!` v1、page 0x800、kernel_addr 0x10008000、tags 0x10000100、header_version 1：
- kernel payload = `gzip(BootShim 192 B + FD 4,194,304 B)` = 979,578 B，解压 4,194,496 B（`0xC0` shim + `_FVH` 在 0xe8 ⇒ FD 基址 0xC0，与 keys149 一致）。
- 末尾附加 `Resources/DTBs/vermeer.dtb`（808,716 B，sha `71da2503…`），在三张图（149/152/153）中都能**整段原样找到**（偏移 0xef9d3 / 0xefa7a / 0xef9d3，差值 167 B = gzip 长度差），DTB **未变**。
- BootShim sha `701786ea…`（与 keys149 相同），`FD_BASE=0xA7100000`、`FD_SIZE=0x400000` 未变。

---

## 5. Guid.xref

keys152 与 keys149 的模块集合完全相同（唯一变化是 Menu 的二进制内容），因此 `Guid.xref` **无增删**；keys152 的快照保存在 `_tools/guid-keys152.xref`（299 行）。关键行仍在：`DxeCore`、`PmicDxe`、`VermeerDtbExtnDxe`、`VermeerLogDiskDxe`、`VermeerMenuDxe`、`AcpiTableDxe`、`UsbConfigDxe`、`UsbInitDxe`、`UsbMsdDxe`、`UsbfnDwc3Dxe`、`UsbDeviceDxe`、`ClockDxe`、`HALIOMMU`；`UFSDxe` 不在 FV（预期）。

---

## 6. 上机预期与判读表

| 现象 | 含义 |
|---|---|
| keys153 能过 `MMU: enabled` 并继续 | 刷机链/硬件正常，可继续 bisect |
| keys152 能过 `MMU: enabled`，出现 `[MENU152] minimal menu: read-only diag...` | 我们 Menu 的**代码路径**本身不致命；再对照 keys149 输出找差异 |
| keys152 打印 `[USB150] pre …` / `[USB152] vbus readonly: HS=… SS=… GCC_GDSCR=…` / `[USB150] post …` 后出现 `[MENU152] diag done - no CpuDeadLoop, returning` | 只读诊断完成并正常交还 BDS（期望路径） |
| keys152 仍卡在 `MMU: enabled`（连 MENU152 都没有） | 与 Menu 内容无关（PEI/DXE 除 Menu 外与 keys149 逐字节一致），应查刷写/传输/硬件状态，而不是继续改 Menu |
| keys152 在 `[USB150] pre …` 之后卡死 | **MMIO 读 DWC3 寄存器本身**在该时点会挂（GCC/DWC3 时钟未开时读可能挂总线）⇒ 下一步 keys152b：连只读 dump 也去掉，只留 Say 打印 |

> keys152 **不会**让 USB 枚举（我们故意不写 RUN_STOP/PRTCAPDIR/VBUS）；它的唯一目的是 bisect "Menu 写操作是否是卡死触发器"。

---

## 7. 回退

- 首选：刷 keys153（= keys149 原样）。
- 之后：keys147d（`22d1d32a…`，USB 诊断 + DtbExtn VBUS）、keys146（`fefa1c2e…`，no-IOMMU 回退）均仍保留。

---

## 8. 本次新增脚本（`D:\本地项目-01\_tools\`）

`k152_restore_mm.py`（恢复 MemoryMapLib USB 行，幂等，check 模式）、`run152b.sh`（touch 源文件后重建 keys152 + 打包 + 复制 + 快照 xref）、`verify152.py`、`k152_menucheck.py`/`k152_srccontext.sh`/`k152_final.sh`/`k152_secdiff.py`/`k152_tail*.py`（离线校验工具）、`patch_usb152.py`（Menu 最小化补丁）。
