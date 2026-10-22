# keys159 报告 — Menu 内嵌最小 DWC3 device EP0 应答（只做枚举，不做数据）

## 1. 目标

keys158 真机仍在早期 RUN 后复位（DEVTEN 残留 + 事件缓冲未配置的假设已由 keys158 修掉，但仍需
验证）。keys159 是备用方案：**不依赖厂商 gadget 栈**，由我们的 Menu 直接扮演 USB device，
把枚举必须的 Device/Config/String 描述符回给主机，让 Windows 至少认成"USB 设备"（不再报
"设备描述符请求失败"）。

## 2. 实现（全部在 `VermeerMenuDxe.c`，只改 Menu 一个模块）

基线 = keys158（早期 bring-up 在 `VermeerDtbExtnDxe`，DEVTEN/GEVNT 已置零）。
Menu 的常驻循环里新增：

| 步骤 | 内容 |
|---|---|
| DMA | `gBS->AllocatePages(AllocateAnyPages, EfiBootServicesData, 4, &Pa)` = 16 KiB、4 KiB 对齐（event buffer 要求）|
| 软复位 | `DCTL(0xC704) = CSFTRST(bit30)`，轮询自清，≤500×1 ms |
| 事件缓冲 | `GEVNTADRLO/HI(0xC400/0xC404)` = DMA PA；`GEVNTSIZ(0xC408) = (1<<31) | 4096`（bit31=中断屏蔽，纯轮询）；`GEVNTCOUNT(0xC40C) = 读回值`（写清零）|
| DCFG | 清零 speed(bit2:0) 与地址(bit9:3) → 高速、地址 0 |
| DEVTEN | `0x7` = disconnect(bit0)+USB reset(bit1)+connect-done(bit2)（**SETUP 不是 DEVTEN 位**，SETUP 通过 EP0 OUT 的 XferComplete 事件通知，见下）|
| EP0 OUT (dep 0) | `DEPSTARTCFG` → `SETEPCONFIG(param0=(0<<1)|(512<<3), param1=(1<<8)|(1<<10)|(0<<25))` → `SETTRANSFRESOURCE(1)` |
| EP0 IN (dep 1) | `SETEPCONFIG(同样, param1 |= (1<<25))` → `SETTRANSFRESOURCE(1)` |
| 使能 | `DALEPENA(0xC720) = 0x3`；arm SETUP TRB（8 字节缓冲）；`DCTL |= RUN_STOP`，轮询 `DSTS.hlt22` |
| 轮询 | 常驻循环每次 `GEVNTCOUNT & 0xFFFF`；非 0 则 invalidate 事件缓冲、逐 4 字节取事件（回绕 4 KiB）、处理完把 count 写回清除 |

### 2.1 DEPCMD / TRB 位组合（从厂商与参考实现抄的）

来自同一颗 Synopsys DWC3、在真机上枚举成功过的参考实现
`_refs/ios-vermeer-lab/xnu/patches/0073-sweet-usb-device-ep0.patch`（并已与
`Silicon/Samsung/SamsungPkg/Include/Device/Dwc3.h`、`UsbfnDwc3Dxe.efi` 反汇编对齐）：

```
DEPCMDPAR2(n) = 0xC800 + 0x10*n   (TRB 地址高 32)
DEPCMDPAR1(n) = 0xC804 + 0x10*n   (TRB 地址低 32)
DEPCMDPAR0(n) = 0xC808 + 0x10*n   (命令参数)
DEPCMD(n)     = 0xC80C + 0x10*n
DEPCMD_CMDACT = 1<<10
SETEPCONFIG=1  SETTRANSFRESOURCE=2  SETSTALL=4  STARTTRANSFER=6  DEPSTARTCFG=9
TRB (16 B): [0]=buf lo [1]=buf hi [2]=len
            [3]=ctl | HWO(bit0) | LST(bit1) | ISP_IMI(bit10) | IOC(bit11)
TRBCTL: SETUP=2<<4  STATUS2=3<<4  STATUS3=4<<4  DATA=5<<4
```

命令执行：写 PAR2/PAR1/PAR0 → 写 `DEPCMD = cmd | CMDACT` → 轮询 `DEPCMD.CMDACT` 清零，
`DEPCMD[15:12]` 为 status（0=成功）。

### 2.2 事件格式（4 字节）

```
bit0      = 1 → device event，type = (ev>>8)&0xF：0=disconnect, 1=USB reset, 2=connect-done
bit0      = 0 → endpoint event：ep=(ev>>1)&0x1F, type=(ev>>6)&0xF, status=(ev>>12)&0xF
          type 1 = XferComplete；type 3 + status 2 = XferNotReady（控制状态阶段）
```

### 2.3 控制传输状态机（照 Linux dwc3 ep0.c）

1. 初始 arm SETUP TRB（缓冲 = DMA+0x1040，8 字节）；
2. XferComplete(state=SETUP) → invalidate 8 字节 → 解析 SETUP → 处理请求；
3. 有数据阶段 → 在 EP0 IN/OUT 上 `STARTTRANSFER`（DATA TRB）→ XferComplete(state=DATA) → 等状态阶段；
4. XferNotReady(status=2) → 启动状态阶段 TRB（有数据阶段用 STATUS3，无数据用 STATUS2）；
5. XferComplete(state=STATUS) → 重新 arm SETUP。

### 2.4 请求处理

| bRequest | 行为 |
|---|---|
| 0x06 GET_DESCRIPTOR | type 1 设备描述符 18 B；type 2 配置描述符 18 B（1 接口 0 端点）；type 3 字符串（0=LangID 0x0409、1="Vermeer"、2="K70 UEFI DEBUG"，UTF-16LE）|
| 0x05 SET_ADDRESS | `DCFG.bit9:3 = addr`，只回 status |
| 0x08 GET_CONFIGURATION | 返回 1 字节 1 |
| 0x00 GET_STATUS | 返回 2 字节 0 |
| 0x09 SET_CONFIGURATION / 0x0B SET_INTERFACE | 仅打印 |
| 其它 | `SETSTALL` 后重新 arm SETUP |

描述符字节表位置（便于后续加 CDC/MSD 类）：

- 设备描述符：`mUsb159DevDesc[18]`（Menu 源码 keys159 块内，紧跟 `Usb159String()` 之前）
  - `bcdUSB=0x0200`、class=0、`bMaxPacketSize0=64`、**VID=0x1209 / PID=0xC101**、
    `bcdDevice=0x0100`、iManufacturer=1、iProduct=2、bNumConfigurations=1；
- 配置描述符：`mUsb159CfgDesc[18]` = 9 B 配置头（bNumInterfaces=1、bmAttributes=0x80、500 mA）
  + 9 B 接口（bInterfaceNumber=0、bNumEndpoints=0、class=0xFF vendor）；
- 字符串表：`mUsb159Strings[3]`（"Vermeer" / "K70 UEFI DEBUG"）；
- **加 CDC/MSD 只需扩 `mUsb159CfgDesc`（加接口/端点描述符）、在 SET_CONFIGURATION 时
  对相应端点做 SETEPCONFIG，并加数据端点事件处理**。

## 3. 打印（屏读用，每行 ≤100 字符）

```
  [USB159] dma=%08x%08x (16 KiB)
  [USB159] soft reset done after N ms GCTL=...
  [USB159] gadget up: GSNPSID=%08x DSTS=%08x hlt22=%d spd=%u
  [USB159] bus reset
  [USB159] connect done speed=%u
  [USB159] setup bm=%02x b=%02x wv=%04x wi=%04x wl=%04x      （每个 SETUP，最多 40 条）
  [USB159] desc type=%02x len=%u                              （每次回描述符，最多 40 条）
  [USB159] address=%u / configured=%u / stall b=%02x
  [USB159] evt=%08x                                           （前 60 个事件，诊断用）
  [USB159] alive                                              （每 ~5 s 一条，证明循环活着）
```

## 4. 产物

| 项 | 文件 | sha256 | 大小 |
|---|---|---|---|
| img | `K70-UEFI-build/Mu-vermeer-keys159.img` = `-fat` = `-marker` | `b2a2289be93aa98866167bc3ad11a080161ef65cd28330a92fd0a9fa44591c0e` | 1,800,192 |
| img 副本 | `K70-UEFI-build/K70-keys159-EP0-MINIMAL.img` | 同上 | 1,800,192 |
| FD | `_k70port_extract/qemu-fw/SILICIUM_UEFI-keys159.fd` | `d694fffe276d6be1b89823fcfeaf6eb614e43ebe31ab0490fb6ac39962088ed6` | 4,194,304 |
| v4 | `Mu-vermeer-keys159-v4.img` | `4dbb282d1d11d65e7e210e367be3daae8399a36c6b67c9f57d5527f6d42c256e` | — |

回退：keys158 img `2cc5a7404d7d8c80fc492b3c3ecee6958cd685bc983c5a2003e7f7f3b23d76d0` /
FD `ad1fdd569405352c383d144a3f443ad73ad0542b301e4e0b7294dfbe3ad9f4d2`；
再往前 keys157 img `8ddc2f58…`。

## 5. 离线验证（`_tools/verify159.py keys159` → PASS）

- outer FFS 2 个；SEC/PEI body 65,440 B sha `cfcfca5e…` **与 keys158 逐字节相同**、GCC×0
  ⇒ PEI 完全没动（keys159 不是 PEI 变更）。
- inner FVMAIN 6,168,584 B；90 模块、**0 增删、恰好 1 个变化**：
  `4f7a1c2e-93b5-4d68-a1e7-6c2b8f5d3a90`（VermeerMenuDxe，FFS body 29,246 → 32,830 B；
  构建产物 `AARCH64/VermeerMenuDxe.efi` 32,768 B sha `56d9072282e07eb1f8e31008fea2f2ef29d1c03568fd2bc5e0b2e91c6abb23c9`）。
- Menu PE 字符串：`MENU159`(UTF-16 ×2)、`USB159`(UTF-16 ×17)、`K70 UEFI DEBUG`(ASCII ×1)、
  `Vermeer`；GCC 立即数 `0x0010F004` 出现 0 次。
- 反汇编抽查：
  - `0x2198 mov w9,#0xc700; movk w9,#0xa60` → 0x0A60C700（DCFG），随后
    `ldr w8,[x9]; bfi w8,w11,#3,#7; str w8,[x9]` = SET_ADDRESS 写设备地址 ✔
  - `0x2ad0 mov w8,#0xc800; movk w8,#0xa60; lsl w9,w0,#4; add w10,w8,w0,lsl#4` =
    `Usb159EpCmd()` 计算 `DEPCMD(n) = 0x0A60C800 + n*0x10` ✔
  - `0x2ae4 mov w22,#0xc8` = 命令轮询上限 200（与源码一致）✔
- 容器：`ANDROID!` v1、page 2048、kernel 1,794,210 = gzip 985,494 + DTB 808,716；
  解压 4,194,496 = 192 B shim + FD 4,194,304，`fd_in_img == FD` True；DTB sha `71da2503…` 不变。

## 6. 上机判读

| 现象 | 结论 |
|---|---|
| `[USB159] gadget up … hlt22=0` + `bus reset`/`connect done` + `setup bm=80 b=06 …` + `desc type=01/02/03` | EP0 通了，主机在枚举 |
| Windows 从 `VID_0000&PID_0002` 变为识别出 `USB\VID_1209&PID_C101`（可能显示 "K70 UEFI DEBUG"） | 最小枚举成功，可以进入下一步（CDC/MSD 类） |
| 只到 `gadget up`，没有 `bus reset`/`connect done` | D+ 上拉/PHY 没生效 → 回 keys158 看 DSTS/PHYCFG、查 QSCRATCH VBUS、GCC 时钟 |
| 有 `bus reset` 没有 `setup` | EP0 OUT 没收到 SETUP → 查 `DALEPENA=0x3`、SETEPCONFIG、TRB 地址（`evt=%08x` 会显示异常事件）|
| `setup` 出现但 `stall`、`desc` 没有 | 请求分派问题（把 `setup`/`evt` 行发我）|
| 又复位 | 记下最后一行；若在 `gadget up` 之后立刻复位，说明软复位/事件缓冲仍有问题 |

注意：本版**故意不做** CDC ACM / MSD 数据通道，配置描述符只有一个 0 端点接口，
Windows 上只会出现一个"USB 设备"节点（可能带感叹号，因为没有类驱动），这是预期。

## 7. 关于"轮询 GEVNTCOUNT 是否可靠"

参考实现（同 SoC 家族、真机枚举成功）就是用 `GEVNTSIZ.bit31=1`（事件中断屏蔽）+ 轮询
`GEVNTCOUNT`，说明在 device 模式下轮询是可靠的；**不要开 GIC 中断**，避免 IRQ 风暴/看门狗。
若真机上出现轮询丢事件，替代方案：在循环里同时轮询 `DSTS.bit22/速度` 并用 `DALEPENA`
重新 arm SETUP，或在 `XferComplete` 后强制 re-arm。

## 8. 构建链

`_tools/run159.sh` = `build_keys158.sh` sed keys158→keys159，并把菜单补丁
`patch_usb157.py` 换成 `patch_usb159.py`；构建 → `pack_keys.sh` → 复制副本。
`_tools/patch_usb159.py` 从 pristine keys149 Menu 生成 keys159 Menu（幂等锚 `[MENU159]`）。
