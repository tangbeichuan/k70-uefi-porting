# keys155 报告：GCC 段映射回 PEI + Menu 只读时钟/GCC 诊断

日期：2026-10-22
构建血缘：`build_keys152.sh` → `build_keys155.sh`（TAG=keys155）
基线：keys152（Menu 只读、PEI = keys149 内存图，真机可进文本 UI 且 presence 全绿）
构建窗口：本次由我执行；lead 负责刷机。

---

## 1. 结论摘要

- keys155 = keys152 + 两处**有意**改动：
  1. **PEI 内存图加回 GCC 段**：`MemoryMapLib.c` 在 USB 行后插入
     `{"GCC", 0x00100000, 0x00200000, AddDev, MMAP_IO, UNCACHEABLE, MmIO, NS_DEVICE}`。
     SEC/PEI FFS：size 65,196 → **65,440**，sha `cfcfca5e…` → `ab1d3c36…`；
     区域名统计 GCC×1 / USB×1 / PERIPH_SS×1 / UFS×0 —— 与当年能启动并读到
     `gcc gdscr=F822F000` 的 keys93/94/95 的 PEI 形状（size 65,440、GCC×1、USB×1、UFS×1）一致。
  2. **Menu 增加只读诊断** `Usb155Diag()`：逐位解码 GCTL/PHYCFG/DCTL/DSTS，只读 GCC
     GDSCR/CBCR(master,sleep,utmi)/phy 候选/BCR 候选/aux(cfg-noc-axi,aggre-axi,ahb2phy,clkref)，
     只读 QSCRATCH HS/SS，并扫描打印 `gcc[0x0F000..0x0F0FF]` 64 个字。**没有任何写操作、无 CpuDeadLoop。**
- 未改 QSCRATCH、未写 DCTL.RUN_STOP、未动 FDF/APRIORI 顺序、未删 USB 行。
- 产物（见 §4）：FD `35b8db13…`；img `c376c20c…`（1,794,048 B）。

## 2. 回答 lead 的 A 问：keys154 的「后段重启」像不像 RUN_STOP 触发的看门狗？

### 2.1 寄存器位解码（依据 `/root/k70/uefi/Silicon/Samsung/SamsungPkg/Include/Device/Dwc3.h`）

`GCTL = 0x00100201`（照片读数）
| 位段 | 字段 | 值 | 含义 |
|---|---|---|---|
| bit0 | DSBLCLKGTNG | 1 | 关闭时钟门控（**不是** core soft reset；CORESOFTRESET 是 bit11） |
| bit1 | （REFCLK_SEL 低） | 0 | |
| bits4-5 | SCALEDOWN | 0 | |
| bit9 | 保留（Dwc3.h 未定义） | 1 | 无法从该头文件解释；可能是 PWRDNSCALE 相关或板级默认 |
| bit10 | SOFITPSYNC | 0 | |
| bit11 | CORESOFTRESET | 0 | 未处于 core 软复位 |
| bits13:12 | PRTCAPDIR | **0** | 照片这版读到 0（同屏 `prtcap=2` 需要 bits13:12=10b）⇒ **该照片值应为 0x00102201**，即"00100201"缺了一位；请现场再确认 |
| bits19+ | PWRDNSCALE | 2 | PHY 掉电缩放=2 |
> 结论：GCTL 无法证明 PHY 上电/时钟开启；且照片值自相矛盾（prtcap=2 与 bits13:12=0 不能同时成立）。

`GUSB2PHYCFG = 0x00102400`
| 位 | 字段 | 值 |
|---|---|---|
| bit31 | PHYSOFTRST | 0（未复位） |
| bit8 | ENBLSLPM | 0 |
| bit6 | SUSPHY | 0（非挂起） |
| bit4 | ULPI_UTMI | 0（UTMI+） |
| bits10-13 | USBTRDTIM | 9（0x2400 = 9<<10） |
> 结论：DWC3 侧"PHY 可用、非挂起、未软复位"。**但 DWC3 的 PHYCFG 不代表 PHY 的供电/时钟已开** —— PHY/eUSB2 的 PLL 与 AHB 时钟由 GCC（GDSCR/CBCR）控制，DWC3 只写控制口。

`DCTL = 0x10F00000`
| 位 | 字段 | 值 |
|---|---|---|
| bit31 | RUN_STOP | **0**（控制器 stopped） |
| bit30 | CSFTRST | 0（不在软复位） |
| bit29 | LSFTRST | 0 |
| bits28:24 | HIRD_THRES | 0x10=16 |
| bits23:20 | 保留（Dwc3.h 未定义） | 0xF |
| bit19 | KEEP_CONNECT | 0 |
> 结论：keys152 打印时控制器处于 stopped 且无复位在跑；我们 keys154 写的正是"置 RUN_STOP=1"。

### 2.2 判断

- **无法从 DWC3 寄存器证明 PHY/时钟已就绪**；若 GCC 里 USB30 GDSCR 的 PWR_ON=0 或 CBCR 的 CLK_OFF=1，那么在时钟关断状态下置 `DCTL.RUN_STOP=1`，DWC3 会开始访问 PIPE/PHY 时钟域，AXI 事务可能无法完成 → 挂死 → 看门狗复位（无 exception handler 输出，屏上表现为"跑到后面直接重启"）。这与"keys154 后段重启、无异常打印"的现象**一致**，但目前**只是高置信假设，未证实**。
- 反向证据（说明也可能不是 watchdog）：keys154 与 keys152 的差别在 Menu 里就是多写了几笔寄存器 + 两次 `gBS->Stall(50ms)`；若 watchdog 触发，通常在数秒内复位，而"后段重启"若发生在更晚（BDS/其它驱动加载之后）则更像别的原因（例如 USB 栈起来后访问未映射寄存器、或之前 §6 的"USB 寄存器写污染"）。**需要现场补拍的屏幕行号/最后一行**才能定位（m03120 提到 8 张照片与 152b 完全重复，无 154 证据）。
- 因此 keys155 **只读、不写 RUN_STOP**：它把"时钟到底开没开"变成可直接判读的屏幕数字，再用 keys156 决定是否"先开时钟再 RUN"。

## 3. keys155 实现

### 3.1 PEI：MemoryMapLib 加 GCC 段
`_tools/patch_gcc155.py`（`add` / `check` / `restore` 三模式，幂等；备份 `/tmp/MemoryMapLib.c.k155bak`）：
```
  {"USB",                 0x0A600000, 0x00200000, AddDev, MMAP_IO, UNCACHEABLE, MmIO,   NS_DEVICE},
+ {"GCC",                 0x00100000, 0x00200000, AddDev, MMAP_IO, UNCACHEABLE, MmIO,   NS_DEVICE},
```
`restore` 后会 `touch` 源文件，避免出现"源文件 mtime 比 .obj 旧 → make 不重编"的 keys151b 陷阱。

### 3.2 Menu：只读诊断（`_tools/patch_usb155.py`，keys152→keys155）
替换 `Usb152Diag` 为 `Usb155Diag`，保留 `Usb150Rd`（`*(volatile UINT32*)addr`）与 `Usb150Dump`，打印（每行 ≤100 字符，屏幕宽度安全）：
1. `[USB155] gcc usb gdscr=%08x cbcr=%08x phy=%08x bcr=%08x`（主行，lead 要求的那一行）
2. `[USB155] gcc cbcr: master/sleep/utmi` + `aux: cfgnoc/aggre/ahb2phy/clkref`
3. `[USB155] gcc dec: gdscr_pwr_on=%d cbcr_clk_off=%d phy_pwr_on=%d bcr_val=%08x`
4. `[USB155] dwc3: GSNPSID/GCTL/GSTS/PHYCFG/PIPECTL/DCFG/DCTL/DSTS` 原始值（复用 Usb150Dump）
5. `[USB155] dwc3 dec: prtcap/run_stop/hlt22/speed/linkst/susphy/enblslpm/phyrst`
6. `[USB155] qscratch readonly: HS=%08x SS=%08x`（只读，不写）
7. `[USB155] gcc[0x0F000+%02x]=…` ×8 行（每行 8 个字，覆盖 0x0F000..0x0F0FC，便于现场直接读出 USB3 PHY GDSCR / USB30_PRIM_BCR 的真实偏移，不依赖我猜的候选值）
8. `[MENU155] …` 两行入口/出口标记，随后 `return EFI_SUCCESS`（无 CpuDeadLoop）。

## 4. 产物

| 项 | 文件 | sha256 | size |
|---|---|---|---|
| FD | `_k70port_extract/qemu-fw/SILICIUM_UEFI-keys155.fd` | `35b8db139d57cf8373f013e5243026f09689b7f365d46f71ee917b30b07c25b8` | 4,194,304 |
| img | `K70-UEFI-build/Mu-vermeer-keys155.img` | `c376c20c8f6975fe0fa0c34b0bc27413838fa7a3421e8edef966f343c36fb49a` | 1,794,048 |
| 交付副本 | `K70-UEFI-build/K70-keys155-GCC-READ.img` | 同上 | 1,794,048 |

回退：keys152（`0f0be4f2…`，Menu 只读+PEI 无 GCC）、keys153（==keys149 原样重打包，`d8784724…`）。

## 5. 离线验证

- **PEI（有意变化）**：SEC/PEI FFS size 65,196→65,440；sha `cfcfca5e…`→`ab1d3c36…`；区域名 GCC×1/USB×1/PERIPH_SS×1/UFS×0（keys93/94/95 为 65,440、GCC×1、USB×1、UFS×1）。
- **Menu（有意变化）**：20,054→22,016 B；UTF-16 串 `MENU155`×2、`USB155`×9、`USB150`×5。
- **Menu 反汇编证明"只读"**：GCC 读取确实编译进去了（`0x1C74 mov w24,#0xf000 / 0x1C80 movk w24,#0x10 → 0x0010F000`，`0x1F84..0x1FDC` 循环读 `[x24..x24+0x1c]`、步长 0x20，上限 0x0010F100；`0x1F00-0x1F28` 读 `0x0016A004 / 0x0018201C / 0x0010502C / 0x0018C010`；`0x1F48-0x1F64` 读 `0x0A6F8810 / +0x20`；`0x1C88-0x1CBC` 读 `0x0A60C110 + 0/8/0x10/0xf0/0x1b0/0x5f0/0x5f4/0x5fc`）。**全部为 `ldr`；对 `[xN]` 的 `str` 共 18 条，均为既有 UI/内部缓冲代码，没有任何一条以 GCC/DWC3/QSCRATCH 地址为基址**（人工核对 18 条：目标均为栈或 Menu 自己的结构体，偏移 < 0x20 或为 xN+xM 索引寻址）。
- **容器**：`ANDROID!` v1、page 0x800、kernel_size 1,788,972；解压 4,194,496 = 0xC0(shim) + FD 4,194,304，`img 内 FD == FD 文件`；尾随 DTB 808,716 B sha `71da2503…` 与 keys152/keys149 相同。
- **Guid.xref**：keys142 全套在（UsbConfigDxe/UsbInitDxe/UsbMsdDxe/UsbfnDwc3Dxe/UsbDeviceDxe/PmicDxe/VermeerDtbExtnDxe/VermeerLogDiskDxe/VermeerMenuDxe/AcpiTableDxe/ClockDxe/HALIOMMU/PmicVerStubDxe），UFSDxe=0。

## 6. 46 个模块的二进制漂移（非有意变化，需说明）

`verify155.py` 用 keys152 FD 做基线逐模块比较：模块数 89/89、0 增删，但**46 个模块 size/sha 发生变化**（Menu 是其中之一；其余例如 17f55a7f .data 3072→3584 B、2d2e62cf 34354→34866 B，另有大量模块 size 相同但 sha 不同）。抽样核实（VermeerLogDiskDxe，size 同为 23,132，sha 不同）：
- PE `.text` 相同大小，差异仅少量立即数/结构体偏移常量（例：`str x0,[x8,#0xc78]` → `str x0,[x8,#0xcc0]`，即某个内部全局/结构体整体位移了 0x48；对应 `.data` 里有全局尺寸变化），`.pdata` 完全相同；
- 该模式与之前 keys151b（同样改过 `MemoryMapLib.c` 后构建）出现的 "46 模块 ±512 B 漂移" 完全一致；
- keys152b/keys154（未改 MemoryMapLib 的构建）与上一版相比 **只有 Menu 一个模块变化**。
**最终结论（已复现验证）**：
- 用同一构建环境重跑 `build_keys152.sh keys152ck` → 89 个模块与 keys152 FD **逐字节相同（changed=0）**；重跑 `build_keys155.sh keys155ck` → 与 keys155 FD **逐字节相同（changed=0）**。⇒ 构建是确定性的，keys155 的 46 模块变化是**由 keys155 的两处改动确定性地引起**，不是环境噪声。
- 机制：这 46 个模块的 payload 里都含平台内存图区域名字符串（`PERIPH_SS`、`USB`、`IMEM`…），比较发现**每个模块都新增了 1 处字符串 `"GCC"`**（keys152 里 0 次 → keys155 里 1 次），且 `.pdata` 完全一致、`.text` 只是引用了移位后的表项偏移。即：这些模块把**平台内存区域描述表**编进了自己的数据（经共享的 platform 库），PEI 加一行 GCC 区域后，它们的表也跟着多一条、整体 +0x244（按 512 对齐后表现为 +512 B）。
- 评价：这是**与本次改动同源、可预期**的变化（区域表新增 GCC 项），不是无关噪声；对本次判读目标（PEI 能否映射 GCC、Menu 读数）无影响。副作用可能是正面的：若其中某个 DXE 模块用该表建 DXE 页表，则 DXE 侧也可能因此拥有 GCC 映射（keys152 崩在 0x0010F004 是因为当时 PEI 表里没有 GCC）。

## 7. GCC 偏移的证据强度

| 寄存器 | 偏移 | 依据 |
|---|---|---|
| USB30_PRIM_GDSCR | `0x0F004` | `_refs/ios-vermeer-lab/xnu/patches/0072-sweet-usb-probe.patch` 明确写 `GCC_USB30_PRIM_GDSCR 0x0f004`（bit31=PWR_ON），并且 keys94 曾在真机打出 `gcc gdscr=F822F000`（bit31=1 表示上电） |
| USB30_PRIM_CBCR(master/sleep/utmi) | `0x0F010 / 0x0F014 / 0x0F018` | 同一 patch 的 `usb_cbcr` 表；bit31=CLK_OFF |
| aux CBCR | `0x0502C / 0x8201C / 0x6A004 / 0x8C010` | 同一 patch（cfg-noc-axi / aggre-axi / ahb2phy / clkref） |
| USB3_PHY_GDSCR | 候选 `0x0F084` | **本地无证据**（本地 uefi 树、ClockDxe、UsbConfigDxe、UsbfnDwc3Dxe 均未出现该偏移）→ keys155 用候选值并扫描 `gcc[0x0F000..0x0F0FF]` 整块，现场可直接从扫描行确认真实偏移 |
| USB30_PRIM_BCR | 候选 `0x0F000` | 同上，无本地证据；扫描块覆盖 |

## 8. 现场判读表（keys155 屏幕）

| 读数 | 含义 | keys156 决策 |
|---|---|---|
| `gdscr_pwr_on=1` 且 `cbcr_clk_off=0` | USB30 时钟/电源已开 | 时钟不是问题；keys154 重启另有原因（查最后一行 / 是否其实没到 Menu 后的 USB 栈代码） |
| `gdscr_pwr_on=0` 或 `cbcr_clk_off=1` | **时钟未开** | keys156：先写 GCC GDSCR bit31=1 / 清 CBCR bit31，再 `fsleep/Stall`，再 `DCTL.RUN_STOP=1`，中间打印 |
| `bcr_val`（0x0F000 或扫描行）非 0 | USB30 仍在复位态 | keys156 先清 BCR 再开时钟/RUN |
| `dwc3 dec` 里 `run_stop=1` 且 `hlt22=0` | 控制器已经 run（ABL 留下的状态） | 不需要任何写 |
| 扫描行出现 0xF82xxxxx/0xF800xxxx 类值 | 找 USB3 PHY GDSCR：bit31 即 PWR_ON | 记录其真实偏移，keys156 用它 |

## 9. 经验教训（写进项目记录）

1. **GCC 段（0x00100000+0x200000）在 DXE 页表默认未映射**：keys152 的崩溃 `PC +0x1C98 / x8=0x0010F004` 就是 Menu 直接读 `GCC_USB30_PRIM_GDSCR` 触发 translation fault；我们的 `VermeerUfsMapDxe` 只映射了 UFS 段，**不是通用映射器**。任何 DXE 阶段要读 GCC 的代码，必须先让 PEI 内存图包含 GCC 段（keys155 的做法），或在 DXE 侧用 `gDS->AddMemorySpace`/建页表自行映射。
2. **写 USB 寄存器会污染后续 boot**：keys153（与 keys149 逐字节相同）在 keys150 跑过之后一度无法进菜单，需断电重启恢复 —— 调试 DWC3 时每版只写必需寄存器，并优先只读。
3. **PowerShell 与 bash 混用会吃掉引号/重定向**：含 `|`、`$`、`>` 的命令一律封装成 `.sh` 再 `bash /mnt/d/...` 执行。
4. WSL 的 `/tmp` 在两次调用之间会被清空：asm/log 要落到 `/mnt/d`。
