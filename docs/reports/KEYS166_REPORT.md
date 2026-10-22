# keys166 交付报告 —— SMMU 旁路对照 + vendor 事件环写序对齐

日期：2026-10-22
基线 = **keys165**（EP0 + pull-up replug + 原始事件追踪 + 20 s 定格）
相对 keys165 唯一改动 = **Menu**；**SEC/PEI 逐字节未动**（SMMU 区早已在 MemoryMapLib 里，见 §3）。

---

## 1. 产物与 sha256

| 文件 | 大小 | sha256 |
|---|---|---|
| `K70-UEFI-build/K70-keys166-SMMU-BYPASS.img` | 1,796,096 B | `8396b592fcac346ff65c110e269dda9bebededef2260dff8579adaf1bd55a565` |
| `K70-UEFI-build/Mu-vermeer-keys166.img`（= `-fat` = `-marker`） | 1,796,096 B | 同上 |
| `_k70port_extract/qemu-fw/SILICIUM_UEFI-keys166.fd` | 4,194,304 B | `ad6146bb80992ff5ae75b161cf32e0a9103349369af0cf5341bdf7aaf173fca7` |
| `K70-UEFI-build/Mu-vermeer-keys166-v4.img` | — | `3d9219e83ca389d0a2d583444dd91d8e06ce31ed1c4fb23f8beb8eeae22928d9` |
| Menu EFI（构建目录） | 26,624 B | `0e1d933a15452a3648ebdde25baed7267e6426556181ddc017ff5e0ef868f257` |

回退：keys165 img `42c004c8e66bfcbe7a605e9f40532e371128e5c3c43b6dec843d85e8b3d943fe`。

---

## 2. 离线验证（PASS）

| 检查项 | 结果 |
|---|---|
| SEC/PEI | 65,440 B，sha `cfcfca5e…`，与 keys165 **逐字节相同**（PEI 未动） |
| inner FVMAIN | 90 模块、0 增删，唯一变化 Menu：25,662 → 26,686 B |
| 容器 | `ANDROID!` v1、page 2048、img 内 FD == FD、解压 4,194,496 = 192 + FD |
| 尾随 DTB | 808,716 B，sha `71da2503…`（不变） |

反汇编证据（keys166 Menu）：
```
1df0: mov  w28, #0xc00          ; S2CR 偏移
1e08: movk w28, #0x1500,lsl #16 ; SMMU base = 0x15000000
1e38: mov  w24, #0xc00
1e50: movk w24, #0x1500,lsl #16
2060: mov  w8, #0x1277          ; DEVTEN = vendor 原值
2120: orr  w8, w8, #0x80000000  ; GEVNTSIZ = (bit31 | size)，纯轮询
3964/3d44: mov w?, #0xffff      ; AllocateMaxAddress 上限 0xFFFFFFFF
```

---

## 3. SMMU 事实（本树源码 + DTB 取证）

- **MemoryMapLib 里本来就有 SMMU 区**：`{"SMMU", 0x15000000, 0x00200000, AddDev, MMAP_IO, UNCACHEABLE, MmIO, NS_DEVICE}`（`MemoryMapLib.c:65`）⇒ Menu 可直接 MMIO 访问，**不需要改 PEI**。
- `xbl_ufs.dtb` 的 `/soc/iort`：
  - `APPS_MMU500_SMMU_APP`：`BaseAddress = 0x15000000`、`Span = 0x80000`、`Model = 0x03`（SMMU-500）、`OutputReference = 0x01`；
  - **`NAMEDNODE_USB0`**（`DevObjectName = "USB0"`）的 `SIDMappings_0`：`InputBase = 0x3000000`、`NumIDs = 1`、**`OutputBase = 0x40`**、`OutputReference = 0x01` ⇒ **DWC3 的 SID = 0x40**（与参考实现 USB-DEBUG.md 里 "SID 0x40 一条 identity SMMU 路由" 完全吻合）。
  - DT 的 `/soc/usb0` 节点**没有 `iommus` 属性**，所以 SID 只能从 IORT 取；`0x60` 是 iort 里别的节点的 OutputBase，按 lead 要求仍作为 fallback 一起尝试。
- 语义参考（本树 `Silicon/Qualcomm/QcomPkg/Library/ArmSmmuDetachLib`）：`SMR_VALID = 1<<31`、SID 在 SMR 低 16 位、`ARM_SMMU_GR0_SMR(n) = 0x800+4n`、`S2CR(n) = 0xC00+4n`；S2CR 的 TYPE 采用 Linux arm-smmu 编码（`0=translate, 1=bypass, 2=fault`）。

> **注意与指令的偏差**：您说 "S2CR 写 0（bypass）"，但 0 在 ARM SMMU-500 里是 **TYPE=translate**（会继续走 CB/页表，仍会 fault）。真正的 bypass 是 **TYPE=1**，所以 keys166 写的是 `S2CR = (1<<16) | 旧CBNDX`。报告里明确记一笔。

---

## 4. keys166 Menu 改动

### 4.1 SMMU 旁路（在 PHY 阶段之后、事件环之前）
```
[166] smmu id0=0004xxxx id1=... smrg=N cb=M     ← ID0/ID1 读出
[166] smmu n=<i> sid=0040 mask=0000 s2cr=...   ← 前 10 个有效 SMR
[166] smmu valid=V of N
[166] smmu bypass sid=0040 n=<i> s2cr 00120040 -> 00010040   ← 命中已存在 SMR：改成 bypass
```
若某个候选 SID **没有**对应有效 SMR（很可能是我们的情况：SEC 阶段 `ArmSmmuDetach()` 把所有 SMR 都 invalid 掉了），则主动**新建一条 bypass 流**（先写 S2CR，再写 SMR 有效位）：
```
[166] smmu created sid=0040 n=<free> smr=80000040 s2cr=00010000
```
fallback：`sid=0060` 同样处理；没有空槽时打印 `no free slot`。

### 4.2 事件环写序与数值对齐 vendor
```
GEVNTADRHI -> GEVNTADRLO -> GEVNTSIZ = 0x80000000 | 0x1000 -> GEVNTCOUNT = 0
DEVTEN = 0x1277（vendor 原值）
```
（之前是 LO→HI、SIZ=0x1000 无 bit31、DEVTEN=0x7。）

### 4.3 DMA 地址 < 4 GiB
`gBS->AllocateMaxAddress` + `DmaPa = 0xFFFFF000`；`bringup done:` 行新增 `evtaddr=%08x%08x`（HI/LO）。

### 4.4 保留
replug（`DCTL.RUN_STOP` off 150 ms → on 150 ms → 等 hlt22）、20 s 窗口、`[166] evt raw=`/`[166] dep evt raw=`、`done: evts/bytes/hlt22/DSTS` + `CpuDeadLoop()`；不碰 CSFTRST/QSCRATCH/GCC。

---

## 5. 屏上预期与判读

```
[MENU166] SMMU bypass + vendor event ring, 20 s
[166] dma=00000000C6xxxxxx (16 KiB)
[166] phycfg=... gctl=... dctl=...
[166] smmu id0=... id1=... smrg=128 cb=...
[166] smmu n=... sid=... s2cr=...
[166] smmu valid=... of ...
[166] smmu bypass/created sid=0040 ...
[166] evt: addr=00000000C6xxxxxx siz=80001000 cnt=00000000
[166] dep n=0 cmd=09 ok=1 st=0 …（EP0 配置 5 条）
[166] replug: pull-up off / on
[166] replug done: hlt22=0 DSTS=… DALEPENA=00000003
[166] gadget up: … / up2: …
[166] bringup done: hlt22=0 phycfg_bit6=0 devspd=… evtaddr=00000000C6xxxxxx
[166] evt raw=…            ← 期望终于出现
[166] poll: cnt=… DSTS=… DCTL=…（每秒）
[166] done: evts=NN bytes=NN hlt22=0 DSTS=…
```

判读：
1. **`evt raw` 出现** ⇒ SMMU 是根因；keys167 把 EP0 描述符应答补全（回 Device/Config/String，VID 1209/PID C101，之后可加 CDC ACM），其它不动。
2. **`evt` 仍 0、但 `smmu created sid=0040` 已打印** ⇒ 旁路已生效仍无事件 ⇒ 按 lead 结论：USB 这条线需要 vendor 的 IOMMU 初始化（`UsbConfigDxe` 的 `ConnectS` 之后那套 SMMU 映射/域建立），今天先收 USB 线回 UFS 主线；若之后再做，就得反汇编 vendor 的 SMMU 映射表。
3. **`smmu id0=00000000`** 或打印里 smrg=0 ⇒ SMMU 区访问异常（时钟/映射），把屏照给我。
4. **`smmu valid=0 of 128`** 是预期现象（SEC 已 detach 全部 SMR），此时走 `created` 路径，说明旁路是"新建"而非"改已有"。

若 created 后仍无事件，下一轮可加：`SMMU` TLB 失效（`TLBIALL`）后再 arm；以及把候选 SID 扩成 `0x40,0x41,0x60`（USB0 若有多个 stream）。

---

## 6. 备注
- 20 s 窗口结束 `CpuDeadLoop()` 定格；EP0 描述符 / QSCRATCH / GCC 均未改动。
- 构建可复现；与 keys165 的唯一模块差异是 Menu（见 §2）。
