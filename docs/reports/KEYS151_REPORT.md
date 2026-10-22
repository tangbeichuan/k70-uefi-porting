# keys151 报告 — 「卡在 MMU: enabled」取证 + 两个候选镜像

日期：2026-10-22 10:0x（Asia/Shanghai）
基线：keys149（能启动，屏幕有 `[MENU149]`/`[USB149]`）；指令来源 m02721。

---

## 0. TL;DR

1. **keys151 与 keys150 镜像字节完全相同**（img sha256 `72249c0b…`、FD sha256 `22733b6e…`）。这不是偶然：同一条血缘重建一次，产物完全可复现。⇒ 说明 keys150 的改动只落在 **1 个 DXE 模块（VermeerMenuDxe）**，SEC/PEI/FV 布局一个字节都没变。
2. **能启动的 keys149 镜像里本来就有 MemoryMapLib 的 USB 行**：它在 SEC/PrePi 的 65,196B TE 镜像内偏移 `0xe5b0`（含 `"USB"` 与 `0x0A600000`），keys149 与 keys150 的这段 **SEC FFS body sha 都是 `cfcfca5efb6b80fe`**。⇒ 「PEI 内存图在 149→150 之间被改」不成立。
3. `"MMU: enabled"` 由 **SEC/PrePi 阶段**打印（`Silicon/Silicium/SiliciumPkg/Library/MemoryInitPeiLib/MemoryInitPei.c:152`），其后才轮到 DXE；这段代码在两版镜像里逐字节相同。⇒ 卡死**无法用镜像内容差异解释**，优先排查刷写/引导路径（`fastboot boot` vs `flash`、A/B 槽位、手机侧镜像是否就是本次生成的文件）。
4. 已按指令同时产出 **keys151b（删掉 MemoryMapLib USB 行）** 作为对照；但它与 keys149 的 PEI 有**真实差异**（SEC FFS sha 变 `8dcc2185…`），且因同一 shell 内二次构建触发全量重编（46 个模块有 ~512B 级的代码生成噪声），**不是干净的单变量对照，不建议先刷它**。

---

## 1. 交付物（sha256）

| 用途 | 文件 | 大小 | sha256 |
|---|---|---|---|
| **keys151 镜像（推荐先刷）** | `K70-UEFI-build/Mu-vermeer-keys151.img` | 1,794,048 B | `72249c0b3e9cb1280c9b4134e049e58347ff57761647767ee06bdb106168d6e4` |
| 交付副本（同 sha） | `K70-UEFI-build/K70-keys151-NO-PEI-CHANGE.img` | 1,794,048 B | 同上 |
| keys151 FD | `_k70port_extract/qemu-fw/SILICIUM_UEFI-keys151.fd` | 4,194,304 B | `22733b6e51124277cbd7301d6504a97a1755eedf22ed155d767bcd5e522db1bf` |
| **keys151b 镜像（删 USB 行，对照用）** | `K70-UEFI-build/Mu-vermeer-keys151b.img` | 1,794,048 B | `84841bc96d0252fbc4018c60885d7d902ec41f30278be7cf0d43233e60fdbd2a` |
| 交付副本（同 sha） | `K70-UEFI-build/K70-keys151b-USBROW-REMOVED.img` | 1,794,048 B | 同上 |
| keys151b FD | `_k70port_extract/qemu-fw/SILICIUM_UEFI-keys151b.fd` | 4,194,304 B | `855dba24bb4cf848b9e68d222a060b96696f77970f93129d128be4ee9d702260` |

参照基线：

| 基线 | sha256 |
|---|---|
| keys149 img（能启动） | `d8784724add3a60007cbd887eb719455b1144172667c7feaec224d8ade19f744` |
| keys149 FD | `fdc529e91f69f0f1c5b5b0d8667933aafef545f02a098e778f14ecdfb2d5693b` |
| keys150 img（= keys151 img，卡死那版） | `72249c0b3e9cb1280c9b4134e049e58347ff57761647767ee06bdb106168d6e4` |
| keys150 FD | `22733b6e51124277cbd7301d6504a97a1755eedf22ed155d767bcd5e522db1bf` |

---

## 2. 任务清单逐项答复

### 2.1 MemoryMapLib USB 行
- 当前工作树 `Platforms/Xiaomi/vermeerPkg/Library/MemoryMapLib/MemoryMapLib.c`：**43 行 region，含第 61 行 `{"USB", 0x0A600000, 0x00200000, AddDev, MMAP_IO, UNCACHEABLE, MmIO, NS_DEVICE}`**；文件 mtime **Oct 21 21:05**，早于 keys140–keys150 的全部构建。
- 该行的存在性可直接从镜像验证：`_tools/k151_peimap.py` 解出 FD 里 SECURITY_CORE FFS 的 `0x12` section（65,196 B TE 镜像），其中 `"USB"` 出现 1 次、`0x0A600000` 位于偏移 `0xe5b0`；**keys149 与 keys150 完全一致**。
- 因此 keys151（保留该行）才是 keys149 的 PEI 原样；keys151b 才是"删行"版。两次构建都做了 restore（当前工作树行数已回到 1），备份在 `/tmp/MemoryMapLib.c.k151bak`（WSL 的 /tmp，重启会丢）。

### 2.2 不再用 MemoryMapLib 加 USB 映射 / DXE 侧映射
- keys151 **没有**新增任何 PEI 映射，也没有改 `VermeerUfsMapDxe`。
- 事实依据：keys149/keys150 真机已经能读到 `0x0A600000` 的 DWC3 寄存器（`[USB149]`/`[MENU150]` 的 dump 有值）⇒ 运行期该段可访问，基线 PEI 表里的 USB 行已覆盖，DXE 侧无需再加 `gDS->AddMemorySpace`/建页表。
- 若后续要动 DXE 映射，按你的要求走 `VermeerUfsMapDxe`（它已有 `gDS->AddMemorySpace` + `SetMemorySpaceAttributes` 且 UFS 段验证过），不要碰 MemoryMapLib。

### 2.3 keys151 = keys149 + 仅 DXE 最小补丁
- keys151 与 keys149 的 FD 逐模块比较：**90 个模块、无增删、唯一变化 = VermeerMenuDxe**（GUID `4f7a1c2e-93b5-4d68-a1e7-6c2b8f5d3a90`，body 19,030 → 20,054 B）。
- SEC/PEI 部分：两 FD 的 `SECURITY_CORE` FFS body sha 都是 `cfcfca5efb6b80fe` ⇒ **PEI 一字节未动**。

### 2.4 离线自检
| 检查 | keys151 | keys151b |
|---|---|---|
| ① 构建期 MemoryMapLib USB 行数 | 1（保留） | **0（删除）** |
| ② 与 keys149 FD 逐模块 cmp | 仅 1 个模块（Menu），0 增删 | 46 个模块（重编噪声 + SEC/PEI 变化） |
| ③ FD sha256 | `22733b6e…` | `855dba24…` |
| ③ 镜像 sha256 | `72249c0b…` | `84841bc9…` |
| SEC/PEI FFS body sha | `cfcfca5efb6b80fe`（= keys149） | `8dcc21856bce5ea6`（≠ keys149） |
| 镜像容器 | shim 192 B + FD 4,194,304 B（gzip 后 1,788,259 B）+ DTB 808,716 B | 同，DTB 相同 |
| 内嵌 DTB sha | `71da250370a977da…`（= keys149） | 同 |

差异清单（keys151 vs keys149）：
- VermeerMenuDxe：19,030 → 20,054 B（keys150 的 PRTCAPDIR=device 诊断补丁）。
- 其余 89 个模块 sha 全部相同；FD 尾部 trailing 0 字节；outer FV `len=0x400000`、inner FVMAIN `len=0x5df000`、inner 解压长度 `0x5df008` 两版一致；boot.img 头 page=0x800/header_version=1/kernel_addr=0x10008000/tags=0x10000100/ramdisk_size=5 两版一致；gzip 内 BootShim 192 B sha `701786eaa31d9087` 两版一致；`vermeer.toml [uefi_fd] base=0xA7100000 size=0x400000` 未变。

### 2.5 其它 PEI 阶段改动：无
- `/root/k70/uefi` 的 6 个已修改文件（`BootShim/BootShim.S`、`BootShim/Makefile`、`Mu_Basecore`（子模块）、`Silicon/Qualcomm/QcomPkg/Library/PlatformPeiLib/PlatformPei.c`、`SiliciumPkg/Drivers/SimpleFbDxe/SimpleFb.c`、`build_uefi.py`）都是 **Oct 20–21 就存在的基线改动**，不是 keys150 引入；`BootShim.S`/`Makefile` 的 diff 只有 BOM/换行与 `PAINT_MARKER` 编译开关。
- `SiliciumPkg/Sec`、`PlatformPeiLib`、`EmbeddedPkg/PrePi`、FD 布局、`vermeer.toml [uefi_fd]` 均未改；pkg 下 mtime > 02:50 的文件只有构建链会重写的那几个 include/dsc/fdf 与 Menu/KeyProbe/PmicVerStub 源（restore trap 重写 mtime）。
- FD 容量/布局未变：FD 4,194,304 B、outer FV len 0x400000、FVMAIN len 0x5df000 三版一致。

---

## 3. 为什么「卡 MMU: enabled」不太可能是我们镜像的内容问题

| 证据 | 结论 |
|---|---|
| SECURITY_CORE FFS（含 `MMU: enabled` 打印代码 + TE 镜像）两版 sha 相同 | SEC 代码没变 |
| `"MMU: enabled"`/`"Loading DxeCore"` 只存在于 `SiliciumPkg/Sec` 产物，FVMAIN 里没有 | 卡点在 SEC→PEI/DXE 交接处，早于任何 DXE 模块 |
| keys149/keys150 唯一模块差异是 Menu（DXE 驱动） | DXE 内容不可能影响 SEC 阶段 |
| keys151 重建结果与 keys150 逐字节相同 | 构建可复现，不存在"构建污染" |
| 镜像容器、shim、DTB、FD 偏移全部一致 | 刷写载荷结构没变 |
| keys147b（新增独立模块）也曾同样卡 `MMU: enabled` | 该现象与"FV 内容/大小变化"相关，但不等于本因；本次 FV 内容除 Menu 外没变 |

补充说明（keys147b 的历史教训与本轮的区别）：keys147b 卡死时 FVMAIN 内**新增了模块**；而 keys150/151 相对 keys149 **没有增删模块**、FVMAIN 长度也相同（0x5df000），因此不能类比分因为"布局变化"。

---

## 4. 建议的下一步（按优先级）

1. **先在同一 USB 口、同一刷写方式下 boot 现有 keys149 镜像**（sha `d8784724…`），确认它现在仍能启动。
   - 若 keys149 现在也卡 → 环境/刷写问题（`fastboot boot` vs `flash`、A/B 槽位、手机侧文件哈希、供电/线缆），**不要继续改镜像**。
   - 刷前请在手机/主机两端对比 sha256，并确认 `fastboot getvar current-slot` 与写入口一致。
2. 若 keys149 可启动 → 直接 boot keys151（sha `72249c0b…`，内容与 keys150 相同）。若又卡，则唯一变量就是 Menu 模块内容；我可以出 **keys152 = Menu 最小补丁**（只保留 1 行打印、绝不写 DWC3 寄存器、去掉 `CpuDeadLoop()` 路径、不动 RunMenu 引用）做二分。注意：理论上 DXE Menu 影响不到 SEC，这条路径本身就是"排除法"。
3. 想验证 PEI 假设时再刷 keys151b（sha `84841bc9…`，删 USB 行）：若它反而能启动，才说明该行有害——但 keys149 带着该行能启动，所以先验概率低，且它的 46 模块全量重编噪声会引入额外变量。
4. 后续如需**干净单变量对比**，建议：先做一次"空转构建"（同血缘、不改任何源码）把缓存血统固定，再做改动构建；本轮的 keys151 已经证明这条血缘的构建是确定性的。

---

## 5. 相关脚本/日志（均在 `D:\本地项目-01\_tools\`）

`patch_peimap151.py`（USB 行 check/backup/remove/restore）、`run151.sh`（151/151b 双构建 + restore）、`verify151.py`、`k151_cmp.py`（FD 逐模块 diff）、`k151_struct.py`（FD 结构）、`k151_peimap.py`（SEC/PEI 段内 USB 行定位）、`k151_bootimg.py`（boot.img 容器）、`k151_tail.py`（gzip/DTB 尾部）、`k151_img.py`、`k151_moddiff.py`、`k151_stage.sh`（MMU/加载串归属）、`k151_str.py`（模块内标记串）；日志 `b151.log`、`v151.log`、`k151_cmp.log`、`k151_struct.log`、`k151_peimap.log`、`k151_bootimg.log`、`k151_tail.log`、`k151_img.log`、`k151_stage.log`、`k151_mmu.log`、`k151_moddiff.log`、`k151_mk.log`。
