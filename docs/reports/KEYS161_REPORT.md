# keys161 / keys161b 报告 — 彻底去掉 `DCTL.CSFTRST` 的 EP0 方案（对照实验）

## 0. 背景（lead 的真机证据）

- keys158（12:19）能上拉 D+、主机记录到 `USB\VID_0000&PID_0002\…`（现为 PHANTOM 幽灵记录）；
- keys160（含 `DCTL.CSFTRST`）之后主机侧**0 新设备**，连"未知设备"都没有；
- keys160 与 keys158 在 USB 路径上的差别只有 Menu 里那段 `CSFTRST` + PHY 重配 + RUN 顺序。
- 结论（lead 判断，本文同意）：**这块 SoC 上 `DCTL.CSFTRST` 会把 USB PHY/时钟域打进不可
  恢复状态（或直接触发 SoC 复位），必须放弃软复位。**

## 1. keys161 —— 完全去掉 CSFTRST（主包，先发）

源码：`_tools/patch_usb161.py`（由 patch_usb160.py 生成，`[MENU161]` 幂等）。
bring-up 顺序（在 Menu 常驻循环前执行一次）：

1. **不写 CSFTRST**。只做 `GUSB2PHYCFG &= ~(PHYSOFTRST(31) | ENBLSLPM(8) | SUSPHY(6))`，
   然后 `Stall(20 ms)` 让 PHY 稳定；
2. 保证 `DCTL.CSFTRST` 保持 0 且**不脉冲**：仅当读回 bit30==1 时执行
   `DCTL &= ~CSFTRST`（RMW 清位，从不置位）；
3. 事件缓冲按 keys160：`GEVNTADRLO/HI=PA`、`GEVNTSIZ=0x1000`（**bit31=0**，vendor 非屏蔽路径）、
   `GEVNTCOUNT` 写回清、`DEVTEN=0x7`、`DCFG` 高速/地址 0；
4. EP0 OUT/IN 配置、SETUP TRB、描述符与事件状态机**与 keys160 完全一致**；
5. RUN：读 `DSTS.hlt22`；若仍为 1，则 `DCTL.RUN_STOP=0 → Stall(1ms) → RUN_STOP=1`，
   再等 ≤200 ms，最多 3 次（全程不碰 CSFTRST）；
6. RUN 稳定后才 arm SETUP TRB（Linux 顺序）；结束打印
   `[USB161] bringup done: hlt22=? phycfg_bit6=? devspd=?`。

探针（保留 keys160 全部 + 加宽每秒行）：

```
  [USB161] poll: DCTL=%08x DSTS=%08x PHYCFG=%08x SIZ=%08x        （每 1 s）
  [USB161] poll2: hlt22=%d spd=%u devspd=%u cnt=%08x             （每 1 s）
  [USB161] regs/regs2/regs3: …                                    （值变化时）
  [USB161] evt raw=%08x type=%u ep=…                              （前 8 条事件）
  [USB161] dep n=%u cmd=%02x ok=%u status=%x p0=%08x              （每条 DEPCMD）
  [USB161] bringup done: hlt22=%d phycfg_bit6=%d devspd=%u
```

## 2. keys161b —— 最小写入保险版（对照实验）

源码：`_tools/patch_usb161b.py`（由 patch_usb161.py 生成，`[MENU161b]` 幂等）。

与 keys161 的**全部差别**（其余完全相同）：

| 项 | keys161 | keys161b |
|---|---|---|
| PHYCFG 清除位 | `PHYSOFTRST(31) | ENBLSLPM(8) | SUSPHY(6)` | **只清 `ENBLSLPM(8) | SUSPHY(6)`**（不动 PHYSOFTRST）|
| DCTL 写入 | 若 halted 则 RUN_STOP off→on 重试 3 次 | **若已 `run=1 且 hlt22=0` 就完全不写 DCTL**；只有 halted 时才 off→on 重试 |
| 其它（事件缓冲/DEVTEN/EP0/TRB/描述符/探针/打印） | 相同 | 相同 |

用途：如果 keys161b 仍然"主机看不到任何新设备"，说明**连清 PHYCFG 的写都可能有问题
（或 PHY 侧根本不工作）**；如果 keys161b 能上拉而 keys161 不能，则问题出在 PHYSOFTRST
或 RUN 重试；如果两个都不行，则 keys158 的上拉来自 XBL/ABL 遗留状态，我们任何改写都会破坏它。

## 3. 产物

| 项 | 文件 | sha256 | 大小 |
|---|---|---|---|
| keys161 img | `K70-UEFI-build/Mu-vermeer-keys161.img` = `-fat` = `-marker` | `ccf2cceb43734c9a0e1b02e832fa46ef8a03b3f38c4fd26701e6d3224656dbb9` | 1,800,192 |
| keys161 img 副本 | `K70-UEFI-build/K70-keys161-NO-SOFTRESET.img` | 同上 | 1,800,192 |
| keys161 FD | `_k70port_extract/qemu-fw/SILICIUM_UEFI-keys161.fd` | `1549e1dfbb0ccd46d62396bd1c29009b41fbe1b4435677263de07856af8dfb2c` | 4,194,304 |
| keys161 v4 | `Mu-vermeer-keys161-v4.img` | `23423334eea631dffca9742f6bb4b5b1d8b7e1ec929ccf903e167cd63d25f5e5` | — |
| keys161b img | `K70-UEFI-build/Mu-vermeer-keys161b.img` = `-fat` = `-marker` | `8c6095d4c12383418e64c7de9f1516f0da77f35c0ecdbbb0d31bff607fec593b` | 1,800,192 |
| keys161b img 副本 | `K70-UEFI-build/K70-keys161b-MINIMAL-WRITE.img` | 同上 | 1,800,192 |
| keys161b FD | `_k70port_extract/qemu-fw/SILICIUM_UEFI-keys161b.fd` | `30d2c3abf139f2a8fc8fc16ababd9aeadaad9a83f608ca58bdb0c8e1ea3d4918` | 4,194,304 |
| keys161b v4 | `Mu-vermeer-keys161b-v4.img` | `42b0976177cbeb046434d258c7bf08c33f3ea408b6e87894156660b1d513e0d6` | — |

回退：keys160 img `aa7d64e81c502ccd1161e4952fb8e32e08c41ccee6ab69af75adada54169f863` /
FD `7291edd8…`；keys159 img `b2a2289b…`；keys158 img `2cc5a740…`。

## 4. 离线验证（`_tools/verify161.py keys161` → PASS）

- outer FFS 2 个；SEC/PEI body 65,440 B sha `cfcfca5e…` **与 keys160 逐字节相同**、GCC×0；
- inner FVMAIN 6,172,680 B；90 模块、0 增删、**恰好 1 变 = VermeerMenuDxe**
  （34,366 B，内容 sha 变化；`AARCH64/VermeerMenuDxe.efi` 34,304 B
  sha `b0a6c5d4fe6445407c3d9392b2cbf54e7850d32e78a20839a47e24e7bc3915ee`）；
- 反汇编确认**没有 CSFTRST 脉冲**：`0x40000000` 立即数在 Menu 里只出现在无关 UI 代码
  `and x0,x0,#0x40000000`；DCTL 写入只有 RMW 清位与 RUN_STOP 的 off/on；
- Menu 字符串：`MENU161`×2(UTF-16)、`USB161`×26、`bringup done`、`poll: DCTL`、`poll2:`、
  `evt raw`、`dep n=` 均在；GCC 立即数 0；
- 容器：`ANDROID!` v1、page 2048、kernel 1,794,707 = gzip 985,991 + DTB 808,716；
  解压 4,194,496 = 192 B shim + FD，`fd_in_img == FD`；DTB sha `71da2503…` 不变。

**keys161b 同样验证 PASS**（`_tools/verify161.py keys161b`）：

- SEC/PEI 65,440 B sha `cfcfca5e…` 与 keys160 逐字节相同、GCC×0；
- inner FVMAIN 6,172,680 B；90 模块、0 增删、**恰好 1 变 = VermeerMenuDxe**
  （34,366 B；`AARCH64/VermeerMenuDxe.efi` 34,304 B
  sha `b08e0cd256767f0304d4548429a3cbebea2738b210084ea93074b7b6331a8e35`）；
- Menu 字符串 `MENU161b`×2、`USB161b`×27、`bringup done`、`poll: DCTL`、`poll2:`、
  `evt raw`、`dep n=` 全在；GCC 立即数 0；反汇编 DCTL 常量只出现在 `0xc700`(DCFG) 侧，
  `0x40000000` 不作为 DCTL 写入出现；
- 容器 kernel 1,794,748 = gzip 986,032 + DTB 808,716；DTB sha `71da2503…` 不变。

两个包与 keys160 的差异都只落在 VermeerMenuDxe，PEI 完全一致（这是"只改 DXE、不动 PEI"
的硬证据）。

## 5. 上机判读（两个包对照）

| keys161 屏上 | keys161b 屏上 | 结论 |
|---|---|---|
| `bringup done: hlt22=0 phycfg_bit6=0` + `poll` 行里 DCTL bit31=1 | 同 | 控制器运行态，继续看事件 |
| 有 `evt raw`（type=2 connect done，甚至 type=1/endpoint） | 同 | 枚举在走，PC 可能已有 VID |
| `hlt22=1` 重试 3 次仍 1 | 同 | RUN 无法生效 → XBL/ABL 可能把 core 停在 halt，需要先检查 GCTL/时钟 |
| 无任何 `evt raw`、`cnt=0` | 同 | 事件没生成（GEVNTSIZ bit31=0 下中断未处理？）；下一步试 bit31=1 |
| 主机仍 0 新设备 | 主机仍 0 新设备 | 我们的写破坏 PHY 状态，或不写也上不了拉 → 回 keys158 状态对比（keys158 有上拉）|
| 主机仍 0 | 主机能看到未知设备 | 问题在 keys161 的 PHYSOFTRST/RUN 重试，改用 161b 路线 |
