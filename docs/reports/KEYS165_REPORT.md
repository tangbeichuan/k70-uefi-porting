# keys165 交付报告 —— EP0 就绪后的"D+/软断开→重连"强制主机重新枚举

日期：2026-10-22
基线 = **keys164**（EP0 gadget + 原始事件追踪 + 清屏 + 停机）
相对 keys164 唯一改动 = **Menu**（新增 replug 时序 + 事件窗口 8 s→20 s）。

---

## 1. 产物与 sha256

| 文件 | 大小 | sha256 |
|---|---|---|
| `K70-UEFI-build/K70-keys165-REPLUG-EP0.img` | 1,796,096 B | `42c004c8e66bfcbe7a605e9f40532e371128e5c3c43b6dec843d85e8b3d943fe` |
| `K70-UEFI-build/Mu-vermeer-keys165.img`（= `-fat` = `-marker`） | 1,796,096 B | 同上 |
| `_k70port_extract/qemu-fw/SILICIUM_UEFI-keys165.fd` | 4,194,304 B | `0a045f6ff75c2de90900390fbd451d9f253b6577d5fdd3019be420509eb22368` |
| `K70-UEFI-build/Mu-vermeer-keys165-v4.img` | — | `44be83d569c1285904611702c495f1cfafe23eca06f82bf33a3454721c856261` |
| Menu EFI（构建目录） | 25,600 B | `e12dac088e778e0e0b4fd1d01be9fb670377a0460d0eb142cb3e2607dfb4ea11` |

回退：keys164 img `493211b646e9d086fb5106fdc5e5f7bc75e757c9dd7ffb5220420cc98a40afe3`。

---

## 2. 相对 keys161（同基线）的差异（离线验证 PASS）

| 检查项 | 结果 |
|---|---|
| SEC/PEI | 65,440 B，sha `cfcfca5e…`，与 keys161 **逐字节相同** |
| inner FVMAIN | 90 模块、**0 增 0 删**，唯一变化 Menu：34,366 → 25,662 B |
| 容器 | `ANDROID!` v1、page 2048、kernel 1,790,929 B = gzip(192 B shim + FD)、解压 4,194,496 = 192 + 4 MiB、img 内 FD == FD |
| 尾随 DTB | 808,716 B，sha `71da2503…`（与 keys149/152/161/164 相同） |
| Menu 串（UTF-16） | `MENU165`、`[165] evt raw=`、`[165] dep evt raw=`、`[165] poll`、`[165] regs:`、`[165] done: evts=`、`[165] dep n=`、**`[165] replug: pull-up off`**、**`[165] replug: pull-up on`**、`replug done` 全部在 |
| 反汇编 | `mov w24,#0xc704`(DCTL) 在；**`and w8,w8,#0x7fffffff`（清 RUN_STOP）→ `orr w8,w8,#0x80000000`（置 RUN_STOP）成对出现两组**（0x1f20/0x1f40 为 RUN 重试、**0x1f90/0x1fc0 为 replug**）；GCC 0x0F004 立即数 0 处 |

---

## 3. keys165 具体实现（Menu，`VermeerMenuDxe.c`）

初始化顺序（全部在 `Usb165Init()` 内，APRIORI 第 4 位 DtbExtn 已完成早期 PHY/RUN 保活）：

1. 分配 16 KiB DMA（4 KiB 对齐）；清 PHY suspend 位（`GUSB2PHYCFG &= ~(bit31|bit8|bit6)`）+ `Stall(20ms)`；
2. 事件环：`GEVNTADRLO/HI`、`GEVNTSIZ=0x1000`（bit31=0）、`GEVNTCOUNT` 清 0、`DCFG` 清 bits9:0、`DEVTEN=0x7`；
3. EP0 资源：`DEPSTARTCFG → SETEPCONFIG(ep0out/in, mps=512) → SETTRANSFRESOURCE ×2 → DALEPENA=0x3`；
4. RUN 保活：若 `DSTS.DEVCTRLHLT=1` 则 `RUN_STOP` off/on 重试（最多 3 次，**绝不碰 CSFTRST**）；
5. **keys165 新增 replug（关键）**：
   ```
   [165] replug: pull-up off (DCTL.RUN_STOP=0)
   DCTL &= ~RUN_STOP ; Stall(150 ms)
   [165] replug: pull-up on  (DCTL.RUN_STOP=1)
   DCTL |=  RUN_STOP ; Stall(150 ms) ; 等 hlt22==0（≤200 ms）
   if (DALEPENA & 0x3) != 0x3: 打印 "ep cfg redo after replug" 并重做整套 EP0 资源
   [165] replug done: hlt22=? DSTS=? DALEPENA=?
   ```
6. `arm SETUP TRB`（`DEPCMD 6 / STARTTRANSFER`），打印 `gadget up` / `up2` / `bringup done`；
7. 常驻循环：每 1 ms `Poll()`；每 1000 tick 打一行 `[165] poll: cnt=… DSTS=… DCTL=…`；值变化打 `[165] regs:`；
   **窗口 20 s（`mTicks165 >= 20000`）或累计 16 条事件**即退出，打 `[165] done: evts=%u bytes=%u hlt22=%d DSTS=%08x` 后 `CpuDeadLoop()`。

**为什么用 DCTL.RUN_STOP 做 pull-up：**
- DWC3 device 没有独立的 pull-up 控制位；设备模式下 **D+ 上拉由控制器在 `DCTL.RUN_STOP=1`（device ready）时驱动**，清 RUN_STOP 等价于电气断开（Linux 的 `dwc3_gadget_pullup(0→1)` 走的就是 gadget_stop/gadget_start 这组寄存器），这是我们能用的、最贴近内核且不碰 QSCRATCH 的方式；
- QSCRATCH 的 `HS_PHY_CTRL.UTMI_OTG_VBUS_VALID/SW_SESSVLD_SEL` 是 PHY 侧覆盖位（keys147b 用过），但 lead 明确要求 keys165 不写 QSCRATCH；
- 实测旁证：keys162 时 `DCTL=0x80F00000`（bit31=1）同时主机侧能看到 `VID_0000&PID_0002`，说明 RUN_STOP=1 就是"D+ 已上拉、主机可见"的状态；而 keys144 无 IOMMU 时 `DCTL` bit31=0、主机完全看不到设备。

---

## 4. 屏上预期

```
  [MENU165] keys165: EP0 + pull-up replug, 20 s window
  [165] dma=00000000C6xxxxxx (16 KiB)
  [165] evt: addr=00000000C6xxxxxx siz=00001000 cnt=00000000
  [165] dep n=0 cmd=09 ok=1 st=0      ← DEPSTARTCFG
  [165] dep n=0 cmd=01 ok=1 st=0      ← SETEPCONFIG(ep0 out,512)
  [165] dep n=0 cmd=02 ok=1 st=0      ← SETTRANSFRESOURCE(ep0 out)
  [165] dep n=1 cmd=01 ok=1 st=0
  [165] dep n=1 cmd=02 ok=1 st=0
  [165] replug: pull-up off (DCTL.RUN_STOP=0)
  [165] replug: pull-up on (DCTL.RUN_STOP=1)
  [165] replug done: hlt22=0 DSTS=00xxxxxx DALEPENA=00000003
  [165] dep n=0 cmd=06 ok=1 st=0      ← arm SETUP TRB
  [165] gadget up … up2 … bringup done …
  [165] evt raw=XXXXXXXX              ← 期望至少 connect-done(…0201) / reset(…0101)
  [165] dep evt raw=XXXXXXXX          ← 期望 XferNotReady / XferComplete
  [165] poll: cnt=… DSTS=… DCTL=…     ← 每秒
  [165] done: evts=NN bytes=NN hlt22=0 DSTS=00xxxxxx
```
判读：
- **`evts>0`** → 事件环通了；按 raw 值（设备事件 `type=(raw>>8)&0xF`：0/1/2=disconnect/reset/connect-done；端点事件 `ep=(raw>>1)&0x1F`、`type=(raw>>6)&0xF`、`status=(raw>>12)&0xF`）套上一轮报告的表，直接出最终 EP0；
- **`evts` 仍 0** → 见 §5。

---

## 5. 若 `evts` 仍为 0，下一轮的怀疑点（按优先级）

1. **事件缓冲 DMA 地址超过 4 GiB**：`[165] dma=` 高 32 位若非 0，说明 `AllocateAnyPages` 给了高地址；DWC3 若只被 ABL 配成 32 位 DMA，`GEVNTADRHI` 会被忽略 → 事件写进错误地址且**无异常**（静默丢事件）。keys166 改 `AllocateMaxAddress(0xFFFFFFFF)` 强制 <4 GiB，并保证 4 KiB 对齐、不跨 64 KiB 边界。
2. **SMMU/IOMMU 未映射 DWC3 的 SID**：keys143 起 HAL IOMMU 已放回 FV，若 DWC3 的 DMA 走 SMMU 翻译而该 SID 没有 identity 映射，事件写入会被静默丢弃（也不会有 abort）。keys166 可临时回到 keys143b 的"无 HAL IOMMU"配置做对照。
3. **事件环写序/掩码**：vendor 是 `ADDRHI→ADDRLO→SIZ` 且 `SIZ` 在无中断资源时 **bit31=1**（masked 轮询）；我们目前是 `LO→HI→SIZ` 且 bit31=0。keys166 可切到 vendor 顺序 + bit31=1 再试。
4. **DEVTEN 位宽**：vendor 写 `0x1277`（bits 0,1,2,4,5,6,9,12），我们只写 `0x7`；keys166 可改 `0x1277`。
5. **replug 后事件环地址被清**：`RUN_STOP=0` 的 stop 路径在部分 DWC3 上会清 `GEVNTCOUNT`/EP 资源；keys165 已对 EP0 资源做了 DALEPENA 回读重做，但**未重写事件环地址**。keys166 在 replug 之后再写一次 `GEVNTADR/SIZ/COUNT` 并回读打印。
6. **主机侧没有真正重新枚举**（Windows 缓存）：看主机 PnP 是否有新的到达时间；可在 `poll` 行里观察 `cmd=06` 之后 `GEVNTCOUNT` 是否变化。

---

## 6. 备注

- keys165 仍然：不写 QSCRATCH、不读 GCC、不写 CSFTRST；描述符 VID `0x1209` / PID `0xC101`。
- 20 s 窗口结束后 `CpuDeadLoop()`，屏幕定格（这是为了保住 trace）；f 需要更长窗口只需改 `mTicks165` 上限。
- 构建可复现；与 keys161 的唯一模块差异是 Menu（见 §2）。
