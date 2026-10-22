# keys160 报告 — keys159 + "为什么没有 SETUP" 强探针（并修掉两个可疑时序）

基线 keys159（keys158 早期 bring-up + Menu 内最小 EP0 gadget），**只改 Menu 一个模块**，PEI 一字节未动。
lead 真机 keys159：PC 仍报 `USB\VID_0000&PID_0002` + "未知 USB 设备(设备描述符请求失败)"，
`Get-Disk` / `Win32_SerialPort` 无新设备 ⇒ D+ 上拉成立、host 在枚举、我方 EP0 无任何 SETUP 响应。

## 1. 自查结论（lead 指定的两项 + DEVTEN 位表）

### 1.1 `GEVNTSIZ.bit31` 语义 = **INTMASK（1=屏蔽事件中断）**，不是事件使能

证据（vendor `UsbfnDwc3Dxe.efi` 0x8bdc-0x8c40）：

```
GEVNTSIZ(0xC408) 写入值 = (TST w21,#0xff 为 0 ? size|0x80000000 : size)
   → orr w9,w20,#0x80000000      ; 屏蔽版
   → csel w1,w9,w20,eq           ; 无可用中断时选屏蔽版
```

即 vendor 在"没有中断资源"时写 `size|bit31`，有中断时写 `size`；Linux dwc3 同理
（`GEVNTSIZ = size | (event_irq ? 0 : INTMASK)`）。
**结论**：keys159 用 bit31=1（纯轮询）是参考实现（`_refs/ios-vermeer-lab/xnu/patches/0073-sweet-usb-device-ep0.patch`，
同一 DWC3 真机枚举成功）的用法，本身不是 bug 根因。
keys160 按 lead 要求改成写 `size`（bit31=0）——**注意**：这会让事件中断不被屏蔽，
而我们的 Menu 没有 GIC 中断处理程序；若真机出现"复位/中断风暴"，把 `USB160_EVT_SIZE` 改回
`(1U<<31)|4096`（源码就是一行）即可。判读行：`[USB160] evt: addr=… siz=00001000` 表示 bit31=0。

### 1.2 `DEVTEN` 位定义核对 — 0x7 正确；**SETUP 不是 DEVTEN 位**

DWC3 device event 使能位（`Dwc3.h` / databook）：

| bit | 名称 | 含义 |
|---|---|---|
| 0 | DISSCONNEVTEN | disconnect |
| 1 | USBRSTEVTEN | USB reset |
| 2 | CONNECTDONEEN | connect done |
| 3 | ULSTCHNGEN | link state change |
| 4 | WKUPEVTEN | wakeup |
| 5 | ERRATICERREVTEN | erratic error |
| 6 | SOFEN | SOF |
| 7 | EOPFEN | EOP |

vendor 用 `0x1277`（bits 0,1,2,4,5,6,9,12），我们用 `0x7` = disconnect+reset+connectdone，
**恰好是我们需要的三位**。SETUP/枚举事件不走 DEVTEN，而是 EP0 OUT 传输出来的
endpoint event（`type=1 XferComplete, status=SETUP`；状态阶段用 `XferNotReady+status=2`）——
事件格式见 KEYS159_REPORT §2.2。

### 1.3 CSFTRST 与 PHY：**这里发现真 bug（keys159）并已修**

- 软复位等待：`DCTL(0xC704).CSFTRST`（bit30）自清零（databook 语义，DSTS 没有 CSFTRST 字段），
  keys159 轮询的是 DCTL bit30，写法正确；keys160 额外打印复位耗时与 `DCTL/GCTL` 复核。
- **真 bug**：`DCTL.CSFTRST` 会把 core 内 dev 侧寄存器恢复到默认值，**包括
  `GUSB2PHYCFG(0xC200)` 的 `SUSPHY(bit6)=1`**。keys159 的顺序是：
  早期 `VermeerDtbExtnDxe` 里清一次 PHYCFG → Menu 里 CSFTRST 软复位 → … → 枚举。
  软复位把 SUSPHY 又置回 1 ⇒ **PHY 处于 suspend，根本没有向上游发 SETUP**
  （host 侧只看到 D+ 上拉/连接，描述符请求自然超时——与"VID_0000 描述符请求失败"完全吻合）。
  keys160 修复：CSFTRST 完成后**重新清 `SUSPHY/ENBLSLPM/PHYSOFTRST`** 并 `Stall(20ms)` 让 PHY 稳定，
  再打印 `[USB160] phycfg=…` 供现场核对（bit6 必须为 0）。
- 顺带修正 arm 顺序：keys159 是"先 arm SETUP TRB 再 RUN"；keys160 改为
  **先 `DCTL|=RUN_STOP` → 轮询 `DSTS.hlt22==0` → 再 arm SETUP TRB**（Linux dwc3 的顺序）。

**预期**：这次应至少能看到 `[USB160] evt raw=… type=2 ep=dev`（connect done）以及
`setup bm=80 b=06 …`。若仍只有连接无事件，判读表见 §4。

## 2. keys160 新增探针（Menu 常驻循环）

| 探针 | 打印（短，屏读） | 频率 |
|---|---|---|
| 状态行 | `[USB160] poll: DSTS=%08x hlt22=%d spd=%u evtcnt=%08x` | 每 1 s |
| 变化全量 | `regs: DCFG=… devspd=… devaddr=… DALEPENA=…` / `regs2: DEVTEN/DCTL/PHYCFG/GEVNTSIZ` / `regs3: DEPCMD0/PAR0(0)/evtaddr` | 仅值变化时 |
| 原始事件 | `[USB160] evt raw=%08x type=%u ep=dev`（device event）/ `… type=%u ep=%u`（endpoint event） | 前 8 条 |
| DEPCMD | `[USB160] dep n=%u cmd=%02x ok=%u status=%x p0=%08x`（超时打 `dep n=… timeout`） | 每条，≤80 条 |
| 保留 | `bus reset` / `connect done speed=…` / `setup bm=.. b=.. wv/wi/wl` / `desc type=.. len=..` / `address=` / `configured=` / `stall` | 事件驱动 |

初始化阶段另打：`dma=…`、`soft reset done … DCTL/GCTL`、`phycfg/gctl`、`evt: addr/siz/cnt`、
`gadget up: GSNPSID/GCTL/DCFG/DEVTEN`、`up2: DALEPENA/DSTS/hlt22/spd`。

## 3. 产物

| 项 | 文件 | sha256 | 大小 |
|---|---|---|---|
| img | `K70-UEFI-build/Mu-vermeer-keys160.img` = `-fat` = `-marker` | `aa7d64e81c502ccd1161e4952fb8e32e08c41ccee6ab69af75adada54169f863` | 1,800,192 |
| img 副本 | `K70-UEFI-build/K70-keys160-EVTRACE.img` | 同上 | 1,800,192 |
| FD | `_k70port_extract/qemu-fw/SILICIUM_UEFI-keys160.fd` | `7291edd8241653aa50c6088511acc62f032056214740982cc7a38f7240f152b7` | 4,194,304 |
| v4 | `Mu-vermeer-keys160-v4.img` | `cce6fca608458c43d1fafdfd20f4502f2cba7effe942e00ac6197931088d2492` | — |

回退：keys159 img `b2a2289be93aa98866167bc3ad11a080161ef65cd28330a92fd0a9fa44591c0e` /
FD `d694fffe276d6be1b89823fcfeaf6eb614e43ebe31ab0490fb6ac39962088ed6`。

## 4. 离线验证（`_tools/verify160.py keys160` → PASS）

- outer FFS 2 个；SEC/PEI body 65,440 B sha `cfcfca5e…` **与 keys159 逐字节相同**、GCC×0。
- inner FVMAIN 6,172,680 B；90 模块、0 增删、**恰好 1 变 = VermeerMenuDxe**
  （FFS body 32,830 → 34,366 B；`AARCH64/VermeerMenuDxe.efi` 34,304 B
  sha `7f1e31c761b9389964f79804fddeb1bb14f76b370781f9bcdb136c4ecda5972c`）。
- Menu 字符串：`MENU160`(UTF-16 ×2)、`USB160`(UTF-16 ×26)、`poll: DSTS`、`evt raw`(×2)、
  `regs3:`、`dep n=`(×2)、`K70 UEFI DEBUG`(ASCII)，GCC 立即数 0。
- 反汇编核对：`GEVNTSIZ` 写入值为 `0x1000`（源码 `USB160_EVT_SIZE`，bit31=0）；
  `DCTL` RUN 写 `orr w8,w8,#0x80000000`；`DEPCMD` 基址 `0x0A60C800 + n*0x10`。
- 容器：`ANDROID!` v1、page 2048、kernel 1,794,549 = gzip 985,833 + DTB 808,716；
  解压 4,194,496 = 192 B shim + FD，`fd_in_img == FD`；DTB sha `71da2503…` 不变。

## 5. 上机判读（一次定位）

| 屏上现象 | 结论 / 下一步 |
|---|---|
| `phycfg=00102400`（bit6=0）且随后出现 `connect done`/`evt raw type=2` | PHY 修好了，进入枚举阶段 |
| `phycfg` 的 bit6 仍为 1 | 我们的 PHYCFG 写没生效（映射/地址问题）→ 查 DWC3 基址映射 |
| 有 `gadget up` + `hlt22=0`，但 1 s 内 `evtcnt` 一直 0、无任何 `evt raw` | 事件没生成：把 `GEVNTSIZ` 改回 `(1<<31)|4096`（INTMASK）再试；仍无用则查 GCTL 时钟/PHY |
| 有 `evt raw type=2`（connect done）但无 `evt raw` 的 endpoint event（type=1） | EP0 TRB 未被消费 → 看 `dep n=…` 行里 `SETEPCONFIG/SETTRANSFRESOURCE` 是否 `ok=1 status=0`，以及 `PAR0(0)/DEPCMD0` |
| `dep … ok=0 status=…` | DEPCMD 命令失败，按 status 查（1=无效参数常见于 PAR 地址不对/DMA 不可达）|
| 出现 `setup bm=80 b=06 wv=0100` + `desc type=01 len=18` | EP0 通了；PC 应从 VID_0000 变成 VID_1209/PID_C101 ⇒ 可以进入 CDC/MSD 类 |
| 又整机复位 | 记最后一行；重点怀疑 `GEVNTSIZ` bit31=0 引起的中断（改回 masked 版） |

## 6. 构建

`_tools/run160.sh`（由 build_keys159.sh sed keys159→keys160 生成 build_keys160.sh，
菜单补丁换为 `_tools/patch_usb160.py`）。首次构建因
`VermeerMenuDxe.c: unused variable 'mUsb160PollTicks'`（-Werror）失败，删除该声明后重编成功。
