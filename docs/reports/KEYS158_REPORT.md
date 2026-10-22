# keys158 报告 — DWC3 device 事件路径（DEVTEN/GEVNT）在 RUN 前置零

## 1. 本版解决什么

keys157 真机：早期 bring-up 拉起 DWC3 device 运行态后，主机抓到 `VID_0000&PID_0002`
（设备描述符请求失败），随后手机黑屏并出现新一轮 `MMU: enabled`（=复位）。屏上同时看到
`DEVTEN=00001277`（残留非零，不是我们写的）。真实寄存器地图（vendor `UsbfnDwc3Dxe.efi`
反汇编确认）：

| 寄存器 | 偏移 | 说明 |
|---|---|---|
| DCFG | 0xC700 | device 配置 |
| DCTL | 0xC704 | bit31 RUN_STOP、bit30 CSFTRST |
| DEVTEN | 0xC708 | device 事件使能 |
| DSTS | 0xC70C | bit22 DEVCTRLHLT、bits21:18 link state、bits2:0 speed |
| GEVNTADRLO | 0xC400 | 事件缓冲地址低 32 |
| GEVNTADRHI | 0xC404 | 事件缓冲地址高 32 |
| GEVNTSIZ | 0xC408 | 事件缓冲大小 |
| GEVNTCOUNT | 0xC40C | 事件计数（写任意值清零） |

（注意：lead 消息里的 `0x0A60C714/718/71C` 不是 GEVNT 组；GEVNT 组在 `0xC400..0xC40C`，
由 vendor `UsbfnDwc3Dxe` 在 0x8bdc-0x8c40 处写 `0xc404/0xc400/0xc408/0xc40c` 证实。为了
对照，本版仍把 `0xC710/714/718/71C` 的原始值打印出来。）

**根因假设**：RUN_STOP 之后主机开始发复位/SETUP，控制器因 DEVTEN≠0 产生 device 事件，而
事件缓冲地址未被任何驱动合法配置（很可能是 0）→ 事件 DMA 写 0x0 → AXI 解码错误 → SError
→ 复位。与"主机上设备出现一下、随即重启"吻合。

## 2. 改动（只改 `VermeerDtbExtnDxe.c` 早期 bring-up 块）

顺序：读并打印 → **关事件** → 读回验证 → PHYCFG 清位 → RUN_STOP → 轮询 hlt22 → 再打印。

```
[USB158] pre        : GCTL PHYCFG DCTL DEVTEN DSTS
[USB158] evt pre    : ADDRLO ADDRHI SIZ COUNT
[USB158] alt pre    : 710 714 718 71C   （对照 lead 消息里的偏移，只读）
DEVTEN(0xC708)=0 ; GEVNTADRHI(0xC404)=0 ; GEVNTADRLO(0xC400)=0 ;
GEVNTSIZ(0xC408)=0 ; GEVNTCOUNT(0xC40C)=<读到的值> ; MemoryFence
[USB158] evt off    : 读回 DEVTEN/ADDRLO/ADDRHI/SIZ/COUNT
if (DCTL.RUN_STOP==0):
    GUSB2PHYCFG &= ~(SUSPHY(6)|ENBLSLPM(8)|PHYSOFTRST(31))
    DCTL |= RUN_STOP
    poll DSTS.DEVCTRLHLT==0 (≤300×1ms, gBS->Stall(1000))
    [USB158] early run : polls=… PHYCFG DCTL DSTS hlt22 run DEVTEN ADDRLO SIZ
else:
    [USB158] early run : already running … events kept off DEVTEN=…
```

反汇编核对（DtbExtn PE，x26 = DWC3 base + 0xC200）：

| 地址 | 指令 | 语义 |
|---|---|---|
| 0x2130 | `ldr w6,[x26,#0x500]` | 读 GEVNTADRLO (0xC400) |
| 0x2134 | `ldr w7,[x26,#0x504]` | 读 GEVNTADRHI (0xC404) |
| 0x2140 | `ldr w8,[x26,#0x508]` | 读 GEVNTSIZ (0xC408) |
| 0x2144 | `ldr w9,[x26,#0x50c]` | 读 GEVNTCOUNT (0xC40C) |
| 0x21ac | `ldr w21,[x26,#0x50c]` | 同一批读（early pre 打印） |
| 0x226c | `str wzr,[x26,#0x508]` | **DEVTEN = 0** |
| 0x2270 | `str wzr,[x26,#0x204]` | GEVNTADRHI = 0 |
| 0x2274 | `str wzr,[x26,#0x200]` | GEVNTADRLO = 0 |
| 0x2278 | `str wzr,[x26,#0x208]` | GEVNTSIZ = 0 |
| 0x227c | `str w24,[x26,#0x20c]` | GEVNTCOUNT = 读到的值（写清零） |
| 0x2284 | `ldr w21,[x26,#0x508]` 起 | 读回四寄存器（evt off 打印） |
| 0x22a8 | `tbnz w19,#0x1f` | DCTL bit31 已置则跳过 |
| 0x22ac/22b4/22bc | mask `0xfebf/0x7fff` → `str w8,[x26]` | PHYCFG 清 SUSPHY/ENBLSLPM/PHYSOFTRST |
| 0x22c4/22c8 | `orr #0x80000000` → `str [x26,#0x504]` | DCTL.RUN_STOP=1 |
| 0x22dc/22e4 | `ldr [x26,#0x50c]` + `tbz #0x16` + Stall(1000) | 轮询 DSTS.hlt22 |

DEVTEN 由厂商 `UsbfnDwc3Dxe.Start()` / `UsbConfigDxe` 在后续自行重新编程（它们会先配事件缓冲），
本驱动只负责"在把 core 拿出 halt 之前，确保事件路径是关的"。

Menu 相比 keys157 完全未变（只读常驻、不返回 BDS、不写 QSCRATCH、不读 GCC）。

## 3. 产物

| 项 | 文件 | sha256 | 大小 |
|---|---|---|---|
| img | `K70-UEFI-build/Mu-vermeer-keys158.img` = `-fat.img` = `-marker.img` | `2cc5a7404d7d8c80fc492b3c3ecee6958cd685bc983c5a2003e7f7f3b23d76d0` | 1,798,144 |
| img (副本) | `K70-UEFI-build/K70-keys158-DEVTEN-CLEAR.img` | 同上 | 1,798,144 |
| FD | `_k70port_extract/qemu-fw/SILICIUM_UEFI-keys158.fd` | `ad1fdd569405352c383d144a3f443ad73ad0542b301e4e0b7294dfbe3ad9f4d2` | 4,194,304 |
| v4 | `Mu-vermeer-keys158-v4.img` | `24acb30b17b2d6013fd9183f9774e7eb9dd9b2710354a3d26cb5d456059def06` | — |

回退基线 keys157：img `8ddc2f588bff0d62a7966aa58b26c3d141cd4b71797327f7df91052f8b633756`、
FD `0e39c250ab87444954ccd1d54b2a28d2e6fa89686992a77851db41015a9f3db5`。

## 4. 离线验证（`_tools/verify158.py keys158` → PASS）

- outer FFS：2 个；SEC/PEI body **65,440 B sha `cfcfca5e…` 与 keys157 逐字节相同**，GCC×0。
- inner FVMAIN 6,164,488 B；90 个模块、**0 增删、恰好 1 个变化**：
  `5b21e7c4-3d18-4f6a-9a20-8c7e51fd42b9`（VermeerDtbExtnDxe FFS body 31,300 B；
  PE 31,232 B sha `dc4b559f01f88dfa78b71e81e4c9ee9164b612f1d4b9f25b971850ca4c17dfd5`）。
  这符合"预期只有 VermeerDtbExtnDxe 变化"。
- PE 内标记：`USB158`×6、`evt off`×1、`early run`×2、`[VBUS]`×4、`selftest vadc`×2。
- 容器：`ANDROID!` v1、page 2048、kernel 1,792,397 = gzip 983,681 + DTB 808,716；解压 4,194,496
  = 192 B shim + FD 4,194,304，`fd_in_img == FD 文件` True；DTB sha `71da2503…`（与 keys149 起各版相同）。

## 5. 上机判读

出现顺序应为：
```
[DTBEXTN] … 
[USB158] pre : … DEVTEN=00001277 …
[USB158] evt pre : ADDRLO=… ADDRHI=… SIZ=… COUNT=…
[USB158] alt pre : 710=… 714=… 718=… 71C=…
[USB158] evt off : DEVTEN=00000000 ADDRLO=00000000 ADDRHI=00000000 SIZ=00000000 COUNT=…
[USB158] early run : polls=… DSTS=… hlt22=0 run=1 DEVTEN=00000000 …
[MENU157] resident loop …   /  [USB157] alive（Menu 仍是 keys157 版）
```

判读表：

| 现象 | 结论 / 下一步 |
|---|---|
| 不再重启，主机出现 `VID_1209`/`VID_2717`/MSD/COM | 事件 DMA 假设成立，厂商栈接管成功 → 继续打通数据通道 |
| 不再重启，主机仍是 `VID_0000&PID_0002` | 复位根因已修，但厂商 gadget 栈没应答 SETUP → keys159 自写最小 EP0（4 KiB 对齐事件缓冲、DEVTEN 只开 CONNDONE/RESET/SETUP、Menu 轮询 GEVNTCOUNT） |
| 仍重启，但 `evt off` 显示 DEVTEN=0 / ADDR=0 | 复位另有来源 → 查 GIC/USB IRQ、GCC 时钟、QSCRATCH VBUS 竞态 |
| `evt pre` 显示 ADDRLO 非 0 且 SIZ 非 0 | 说明事件缓冲本来合法，复位根因要重定位（记录该值回来） |
| 没有 `[USB158]` 行 | DtbExtn 未执行或 USB MMIO 未映射 |

## 6. 回退

keys157（早期 RUN、不开事件）→ keys156（Menu 存活标记）→ keys154（Menu 内 RUN）。

## 7. 构建链

`_tools/run158.sh` = `build_keys157.sh` sed keys157→keys158（patch 链不变，含 `patch_usb157.py`），
构建 → `pack_keys.sh` → 复制副本。

## 8. 附：寄存器偏移来源

- `GEVNT*` = `0xC400/0xC404/0xC408/0xC40C`：vendor `UsbfnDwc3Dxe.efi` 0x8bdc-0x8c40 序列写这四个地址。
- `DEVTEN=0xC708 / DSTS=0xC70C / DCTL=0xC704 / DCFG=0xC700`：vendor 0x3b78/0x3c1c/0x4cb4 与
  `/root/k70/uefi/Silicon/Samsung/SamsungPkg/Include/Device/Dwc3.h` 一致。
