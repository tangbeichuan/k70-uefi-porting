# keys163 交付报告 —— 清屏 + 只读事件追踪 + CpuDeadLoop 停机

日期：2026-10-22
基线：keys162（Menu 只读事件追踪、无 EP0 arm）
本次唯一改动：**VermeerMenuDxe（Menu）**；SEC/PEI、DtbExtn、其它 89 个模块逐字节未动。

---

## 1. 产物与 sha256

| 文件 | 大小 | sha256 |
|---|---|---|
| `K70-UEFI-build/K70-keys163-CLEAR-EVTRACE-HALT.img` | 1,798,144 B | `acdb90e1df5c0d4ea8673a91c9e1c998382fe6759c374290895cfbc22965125e` |
| `K70-UEFI-build/Mu-vermeer-keys163.img`（同 img / -fat / -marker） | 1,798,144 B | 同上 |
| `K70-UEFI-build/Mu-vermeer-keys163-v4.img` | — | `a24ac8ea394c74183866bc95958ecb4588878ac68568fbdcb788cff549524fb2` |
| `_k70port_extract/qemu-fw/SILICIUM_UEFI-keys163.fd` | 4,194,304 B | `48f4e943c046c0346fed2ed3a2ede22a02d635dda6fa7242127a2a421b0835ba` |
| Menu EFI（构建目录） | 29,696 B | `886522c85f7cd787c5f6cf300b70c4b96ccd106ba128f15ac8705fc3d6ac3444` |

回退（已 flash 进 boot_a 的上一版）：`Mu-vermeer-keys162.img` = `c3204d4763c1ad661ca83a7db2663c2b2f34b5515ea6cf016e2d09df6e02f99a`，
FD `6395c711f8aab94205427ab1fde5790b692c5401e0ecd052c5eb8059bb3a06ec`。

---

## 2. 相对 keys162 的差异（离线验证 PASS）

| 检查项 | 结果 |
|---|---|
| SEC/PEI 段 | 65,440 B，sha `cfcfca5e…` 与 keys162 **逐字节相同**（PEI 未动） |
| inner FVMAIN 模块 | 90 → 90，**0 增 0 删**，唯一变化 `4f7a1c2e-93b5-4d68-a1e7-6c2b8f5d3a90 VermeerMenuDxe`：30,270 → 29,758 B |
| 容器 | `ANDROID!` v1、page 2048、kernel 1,793,197 B = gzip(192 B shim + FD)、解压 4,194,496 B = 0xC0 + 4 MiB FD、img 内 FD == FD 文件 |
| 尾随 DTB | 808,716 B，sha `71da250370a977dacc230bd7977ff43f397e388bf02a55c162b22662152c3891`（与 keys149/152/162 相同） |
| Menu 串（UTF-16） | `MENU163`、`[163] init`、`[163] evt`、`[163] poll`、`[163] done` 各 1 |
| 反汇编 | `mov w19,#0xc704`（DCTL）、`mov w20,#0xc40c`（GEVNTCOUNT）均在；**DEPCMD 窗口（0xc800/0xc804/0xc808/0xc80c/0xc81c）访问 = 0**，即没有 arm STARTTRANSFER；文件末尾存在 `b .` 自跳转（CpuDeadLoop） |

---

## 3. Menu 里 keys163 做了什么

1. **整屏清黑**（入口第一件事）
   - `LocateProtocol(GOP)` 成功 → `FillRect(Gop, 0, 0, Width, Height, 0x00000000)`（内部走 `Gop->Blt(..., EfiBltVideoFill, ...)`）。
   - 无 GOP → `ConOut->ClearScreen`（EDK2 UEFI 2.6+）。
   - 之后 `SetAttribute(灰底/黑字)` + 光标 (0,0)，确保 PEI/DXE `Memory Allocation` 旧字被覆盖、后面每行从顶部重写。
2. **重建事件环（只读，不碰 EP0）**
   - 4 KiB DMA 事件环（4 页，属性 UC）：`GEVNTADRLO/HI = 物理地址`、`GEVNTSIZ = 0x1000`（bit31=0=不屏蔽中断）、`GEVNTCOUNT = 0`。
   - `GUSB2PHYCFG &= ~((1<<8)|(1<<6))`（ENBLSLPM / SUSPHY 清 0）+ `Stall(20 ms)`。
   - `DCFG` 清 bits9:0（HS、地址 0）。
   - `DEVTEN = 0x7`（disconnect / USB reset / connect-done 三类设备事件）。
   - `DCTL` **只保活 RUN_STOP=1**（若 hlt22=1 才 off→on 重试，最多 3 次），**绝不写 bit30 CSFTRST**。
3. **屏幕只打短行**（UTF-16，顶部顺序写）
   - `[163] init id=%08x siz=%08x devten=%08x phycfg=%08x` —— GSNPSID / GEVNTSIZ / DEVTEN / GUSB2PHYCFG 回读。
   - 每收到事件：`[163] evt N raw=xxxxxxxx`（最多 8 条；raw=事件环里读出的原始 4 字节）。
   - 每秒：`[163] poll cnt=xxxx DSTS=xxxxxxxx DCTL=xxxxxxxx consumed=xxx`。
   - 结束时：`[163] done evts=xx bytes=xxxx`（evts=总事件数、bytes=累计写回 GEVNTCOUNT 的已消费字节数）。
4. **停机**：循环最多 8000×1 ms（约 8 s），或收到 8 条事件提前结束；打印 `done` 行后 `gBS->Stall(200 ms)` 再打印一次（防止屏刷不过去），最后 `CpuDeadLoop()`。屏幕从此不再滚动。
5. 事件消费严格按字节：`Chunk = GEVNTCOUNT & ~3`（上限 0x1000），处理完把 **Chunk** 写回 GEVNTCOUNT（Linux dwc3 `writel(GEVNTCOUNT(0), count)` 语义，不是条数、不是清 0）。
6. 不动 EP0：无 `DEPSTARTCFG/SETEPCONFIG/SETTRANSFRESOURCE/STARTTRANSFER`，无描述符应答；不写 QSCRATCH；不读 GCC（0x0010F004 立即数 0 处）。

---

## 4. 与 vendor 反汇编的写序对齐（`UsbfnDwc3Dxe.efi`）

| 项 | vendor | keys163 | 结论 |
|---|---|---|---|
| 事件环地址 | `ADDRHI(0xC404)` → `ADDRLO(0xC400)`（0x8bdc–0x8c04） | `ADDRLO` → `ADDRHI` | 语义等价（两者都在 SIZ 之前写完，DWC3 不做顺序检查）；若无事件可试先 HI 后 LO |
| 事件环长度 | `SIZ(0xC408)`，值由 `orr w9,w20,#0x80000000` / 裸 size 用 `csel` 选择（`tst w21,#0xff`，有无中断预算） | `0x1000`（bit31=0） | bit31 = 中断屏蔽位；取值合法 |
| 事件计数 | `COUNT(0xC40C) = 0`（0x8c30） | `0` | 一致 |
| DEVTEN | `0x3c1c` 写 **0x1277**（bits 0,1,2,4,5,6,9,12） | `0x7` | 0x7 覆盖 disconnect/connect/reset；若无事件可试 0x1277 |
| GUSB2PHYCFG | 0x3908 清 bit8、0x3924 清 bit6 | 一次清 bit8+bit6 | 一致 |
| GCTL.PRTCAPDIR | 0x3b34 清 bit16、0x3b48 清 bits13:12 后 `orr #0x2000`（=device 2） | 不写 GCTL（ABL/UsbConfigDxe 已置 device） | 不改，避免副作用 |

vendor 顺序总结：**GEVNTADR → GEVNTSIZ → DEVTEN（DEVTEN 在另一函数、晚于事件环）**；与 keys163 的 LO/HI→SIZ→COUNT→DEVTEN 同序。

---

## 5. 上机预期（屏上应该看到什么）

**正常（事件环生效）**

```
[163] init id=5533300a siz=00001000 devten=00000007 phycfg=00102400
[163] evt 0 raw=xxxxxxxx          ← 典型是 connect-done / reset
[163] evt 1 raw=xxxxxxxx
[163] poll cnt=0000 DSTS=00d28cc4 DCTL=804808d4 consumed=00c
[163] done evts=2 bytes=000c
```
（`id` 应为 `5533300a` = DWC3 GSNPSID；`phycfg` 应看到 bit6/bit8 = 0。）

**A. 有 evt（设备类 bits11:8 = 0/1/2）但没有端点事件** → 说明事件环、PHY、RUN 都正常，问题在 EP0 路径（keys162 就没 arm）；下一步（keys164）可在**确认收到 USB reset / connect-done 之后**再 arm SETUP TRB，并对 EP0 DEPCMD 的返回逐条上屏。

**B. 一条 evt 都没有** → 事件环没生效或连接未建立。按以下顺序排查（下一包 keys164 可逐个试）：
1. `[163] poll` 里 `DSTS` 的 CONNECTSPD(bits2:0) 是否为 0（0=未连接）→ 若一直 0，控制器没看到 D+ 上拉/主机，需要回看 PHYCFG 与 DCTL；
2. 把写序改成 vendor 的 **ADDRHI 先写**；
3. `DEVTEN` 改 **0x1277**；
4. 回读 `GEVNTADRLO/HI`、`GEVNTSIZ` 确认没被清（CSFTRST 已不使用，理论上不会被复位）。

**C. 屏上一片黑、连 `[163] init` 都没有** → Menu 根本没跑到入口或 GOP 清屏后输出失败；说明本轮改动有早期异常（此时看串口 DEBUG `[163]` 镜像行）。

---

## 6. 备注

- keys163 里 **没有**任何 EP0/描述符/SETUP 应答代码，也没有写 QSCRATCH、读 GCC、软复位；如果主机侧仍出现 `VID_0000&PID_0002` 且几秒后设备回 fastboot，那是“BDS 无启动项 → ResetSystem(Shutdown)”的既有行为（keys162 已确认），不是崩溃。
- keys162 已写入 boot_a；回退固件 = `Mu-vermeer-keys162.img`（sha 见 §1）。
- 构建可复现：同一源码目录连续构建两次产物 sha 一致；本包与 keys162 的唯一模块差异即 Menu。
