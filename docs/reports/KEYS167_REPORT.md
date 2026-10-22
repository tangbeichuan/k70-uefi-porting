# keys167 报告 — 最小 EP0 应答器（K70 / vermeer / PmicDxe 项目）

TAG: `keys167`　基线: `keys166`（keys161 血缘 + SMMU bypass + vendor 事件环写序 + replug）
日期: 2026-10-22　构建窗口: 我方

---

## 1. 产物（可直接刷机）

| 文件 | 大小 | sha256 |
|---|---|---|
| `K70-UEFI-build/Mu-vermeer-keys167.img` | 1,796,096 B | `49a6f8774f4e3fb523098b7cb12035b4ded6284bfdd7cebe2fe2e3da71e55cda` |
| `K70-UEFI-build/K70-keys167-EP0-DESC.img`（副本，同字节） | 1,796,096 B | `49a6f8774f4e3fb523098b7cb12035b4ded6284bfdd7cebe2fe2e3da71e55cda` |
| `K70-UEFI-build/Mu-vermeer-keys167-marker.img` | 1,796,096 B | `49a6f8774f4e3fb523098b7cb12035b4ded6284bfdd7cebe2fe2e3da71e55cda` |
| `K70-UEFI-build/Mu-vermeer-keys167-v4.img`（备用变体） | 1,796,096 B | `8195f76a01886ebeb3d176ddefba3db598232ca49fa472c7d85de52fc630bc96` |
| `_k70port_extract/qemu-fw/SILICIUM_UEFI-keys167.fd` | 4,194,304 B | `5dedcaa49eb22bffde37bd928d40663d23042de8447852019a38240208aa094b` |

回退：上一版 `Mu-vermeer-keys166.img` = `8396b592fcac346ff65c110e269dda9bebededef2260dff8579adaf1bd55a565`（SMMU-BYPASS，无 EP0 应答）。
Menu EFI（FV 内）：27,648 B sha256 `b5024e2d9e22df50cb9f331818865033f022387f74b5d43653deb4e33a952e10`。

## 2. 相对 keys166 的改动（只有 VermeerMenuDxe 一个模块）

| 项 | keys166 | keys167 |
|---|---|---|
| Menu 模块 | 26,686 B | 27,710 B（FFS body；PE 27,648 B） |
| PID | `0xC101` | **`0x0001`** |
| 字符串描述符 | 0/1/2 | 0/1/2 + **3="K70-0001"**（iSerialNumber=3 可应答） |
| SETUP 日志 | 无动作名 | `[167] setup bm=.. b=.. wv=.. wl=.. -> <action>` |
| 配置完成标记 | `configured=%u` | `[167] configured cfg=%u` |
| EP0 arm 标记 | 无 | `[167] ep0 armed (setup TRB queued, waiting for host SETUP)` |
| 设备事件 | 仅 reset/connect/disconnect | 先打 `[167] dev evt type=%u` |
| raw 事件上限 | 16 | 40 |
| done 行 | `evts/bytes` | `evts=%u setups=%u hlt22=%d DSTS=%08x` |

离线核对：SEC/PEI 65,440 B sha `cfcfca5efb6b80fe…` **逐字节与 keys166 相同**（PEI 一字节未动）；FVMAIN 内 90 个模块，0 增删，恰好 1 个变化（Menu）；内嵌 DTB 808,716 B sha `71da2503…` 与源相同；容器内 kernel = gzip(192 B shim + FD)。反汇编：无 GCC 0x0010F004 访问；DEPCMD 基址 `0x0A60C800` 立即数在（`mov w8,#0xc800; movk w8,#0xa60,lsl#16`）；设备描述符字节序列 `18,1,0x00,0x02,0,0,0,64,0x09,0x12,0x01,0x00,0x00,0x01,1,2,3,1` 在 EFI 中找到、旧 PID 0xC101 序列 0 处。

## 3. 描述符（最小可通形态）

**设备描述符（18 B）**

| 字段 | 值 |
|---|---|
| bLength / bDescriptorType | 18 / 1 |
| bcdUSB | 0x0200 |
| bDeviceClass/SubClass/Protocol | 0 / 0 / 0 |
| bMaxPacketSize0 | 64 |
| idVendor / idProduct | **0x1209 / 0x0001** |
| bcdDevice | 0x0100 |
| iManufacturer / iProduct / iSerialNumber | 1 / 2 / 3 |
| bNumConfigurations | 1 |

**配置描述符（wTotalLength = 18 B，一个 vendor-specific 接口，0 端点）**

| 字段 | 值 |
|---|---|
| 配置：bLength/type/wTotalLength/bNumInterfaces/bConfigurationValue/iConfiguration/bmAttributes/bMaxPower | 9 / 2 / **18** / 1 / 1 / 0 / 0x80 / 250（500 mA） |
| 接口：bLength/type/bInterfaceNumber/bAlternateSetting/bNumEndpoints/bInterfaceClass/SubClass/Protocol/iInterface | 9 / 4 / 0 / 0 / **0** / **0xFF（vendor）** / 0 / 0 / 0 |

说明：选“最短能通”——单 vendor-specific 接口、0 端点。足够让主机走完 `GET_DESCRIPTOR(device) → SET_ADDRESS → GET_DESCRIPTOR(config) → SET_CONFIGURATION` 到达 configured；Windows 会给它一个“未知/无驱动”的节点，但 VID/PID 会正确显示 1209:0001。若下一步要 COM 口再换成 CDC-ACM（需加 1 个 interrupt + 2 个 bulk 端点并实现 `SET_CONFIGURATION` 后配置端点）。

**字符串描述符**：0=LangID(0x0409)；1="Vermeer"；2="K70 UEFI DEBUG"；3="K70-0001"。越界索引一律 STALL。

## 4. EP0 事务实现（本树 / vendor 寄存器语义）

- 控制器：DWC3 `0x0A600000`，device 模式（`GCTL.PRTCAPDIR=2`，由 ABL/vendor 早期路径设置；我们不再写）。
- 事件环：4 KiB DMA 缓冲 `AllocateMaxAddress(0xFFFFF000)`（< 4 GiB、4 KiB 对齐），
  `GEVNTADRHI ← >>32`（vendor 写序 HI 先）→ `GEVNTADRLO ← 低 32` → `GEVNTSIZ = (1<<31)|0x1000`（bit31=中断屏蔽、轮询模式）→ `GEVNTCOUNT = 0` → `DEVTEN = 0x1277`（disconnect/reset/connect-done + vendor 其余位）。
- PHY 保活：`GUSB2PHYCFG &= ~(1<<8 | 1<<6)`（ENBLSLPM/SUSPHY），Stall 20 ms；`DCTL.RUN_STOP=1`，轮询 `DSTS.DEVCTRLHLT==0`；**绝不写 CSFTRST**。
- SMMU：DT `/soc/iort/NAMEDNODE_USB0` 的 SIDMapping `OutputBase=0x40` ⇒ 对 SID 0x40 建 bypass 流（`S2CR` 先写 `TYPE=1<<16`，再 `SMR.VALID|SID`）；SMMU 基址 `0x15000000` 已在 MemoryMapLib 映射，无需改 PEI。
- 主机枚举失败后重枚举：先 `DCTL.RUN_STOP=0`（软断开/D+ 下掉）→ Stall 150 ms → `DCTL.RUN_STOP=1` → Stall 150 ms（等价 Linux `dwc3_gadget_pullup(0→1)`），随后 arm EP0 SETUP TRB。
- EP0 配置（vendor 顺序）：`DEPSTARTCFG(ep0)` → `DEPCMD_DEPSTARTCFG` 后 `SETEPCONFIG(out/in, mps=64/512)` → `SETTRANSFRESOURCE` → `DALEPENA=0x3`。
- 每收到 SETUP：`DEPCMD_STARTTRANSFER`（即 databook 的 DEPSTRTXFER/STARTTRANSFER 命令）带 UTRD/TRB（ctl: SETUP=2<<4、STATUS2=3<<4、STATUS3=4<<4、DATA=5<<4）；DATA 方向按 `bmRequestType.bit7`；完成后按 vendor 惯例补 STATUS2/STATUS3。
- 请求策略：`bmRequestType` 0x80 的 `GET_DESCRIPTOR(6)` 回 device/config/string（长度取 `wLength` 与描述符长度较小者）；`0x00` 的 `SET_ADDRESS(5)` 写 `DCFG.DevAddr`；`SET_CONFIGURATION(9)` 置 `[167] configured`；其余一律 `DEPCMD_SETSTALL` 并打日志。
- 20 s 窗口后打印 `[167] done: evts=%u setups=%u hlt22=%d DSTS=%08x` 再 `CpuDeadLoop()` 定格。

## 5. 上机该看哪三行

1. **`[167] setup bm=80 b=06 wv=0100 wl=0040 -> desc-device`** — 主机来要设备描述符（这一行出现 = 事件环+DMA+EP0 arm 全部成立，主机真的在枚举我们）。
2. **`[167] setup bm=00 b=05 wv=0005 wl=0000 -> set-address`** 之后 **`[167] configured cfg=1`** — 地址已分配、配置已选定（这两步出现 = 主机认可描述符，走到了 configured）。
3. **`[167] done: evts=N setups=M hlt22=0 DSTS=…`** — 20 s 结束时的总账：`setups>=2` 且 `hlt22=0` 表示链路稳定、我们正确应答。

配套：Windows 设备管理器应出现 `USB\VID_1209&PID_0001`（可能是“未知设备/无驱动”，但 PID 是 0001 而不是 0002 就已经成功）。

## 6. 判读表（故障定位）

| 屏上现象 | 含义 | 下一步 |
|---|---|---|
| `evts=0`、无任何 `[167] evt raw=` | 事件 DMA 仍不通（SMMU 未 bypass 成功 / 事件环地址问题） | 看 `[167] smmu bypass sid=0040` 是否为 1；尝试把 evtaddr 打到更高（仍 <4GiB）或换用 `SIZ bit31=0` |
| 有 `[167] evt raw=`（设备类 0x…01，type=2）但无 SETUP 日志 | 主机在 D+ 后没再枚举，或 SETUP 未变成 EP0-OUT 事件 | 确认 replug 行出现；把 `DEVTEN` 改 0x7 试；确认 `DALEPENA=0x3` |
| 有 SETUP 但都 `-> unknown` / `class/vendor` | 主机发的是标准请求的其它形态 | 补该 `bRequest` 的分支（如 `GET_CONFIGURATION`/`GET_STATUS` 已在实现里） |
| `desc-device` 后 STALL | 描述符长度/内容被拒 | 检查 wLength 与 bMaxPacketSize0；本版 mps=64 |
| 到了 `configured` 但主机报“设备描述符请求失败” | 我们回的数据没被正确取走（STATUS 阶段/方向） | 看 `[167] dep n=…` 每命令 status；核对 DATA/STATUS 阶段 TRB |
| 一切正常但仍无新设备 | 主机侧缓存/端口问题 | 换 USB 口/线；对照 PnP 到达时间 |

## 7. 未改动 / 风险

- PEI（SEC/PEI 65,440 B `cfcfca5e…`）**一字节未动**；MemoryMapLib 的 USB/SMMU/GCC 行保持 keys149 状态（GCC 行 0）。
- 无 CSFTRST、无 QSCRATCH 写、无 GCC 读；SMMU bypass 与 replug 保留（keys166 真机证明无害）。
- 已知局限：0 端点 vendor-specific 配置只会到 “configured、无驱动”；要 COM 口需 CDC-ACM 端点 + 数据通路（后续 keys168 可做）。
- 回退：`Mu-vermeer-keys166.img`（sha 见 §1），仍可看到“主机枚举但描述符请求失败”的现象。
