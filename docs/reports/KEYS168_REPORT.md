# keys168 报告 — 控制台路标（黑屏诊断版）

TAG: `keys168`　基线: `keys167`（EP0 应答器 / SMMU bypass / replug / 20 s 窗口）
日期: 2026-10-22　构建窗口: 我方

---

## 1. 产物

| 文件 | 大小 | sha256 |
|---|---|---|
| `K70-UEFI-build/Mu-vermeer-keys168.img` | 1,796,096 B | `5a02510d4d2fa93c65ac5f40e306995510daff62c0bb0f481ecaee4d1e2fb8db` |
| `K70-UEFI-build/K70-keys168-CONSOLE-MARKERS.img`（副本） | 1,796,096 B | `5a02510d4d2fa93c65ac5f40e306995510daff62c0bb0f481ecaee4d1e2fb8db` |
| `K70-UEFI-build/Mu-vermeer-keys168-marker.img` | 1,796,096 B | `5a02510d4d2fa93c65ac5f40e306995510daff62c0bb0f481ecaee4d1e2fb8db` |
| `K70-UEFI-build/Mu-vermeer-keys168-v4.img` | 1,796,096 B | `56bde002ff871e30febfe3ba839841da02c2aec52bd0eed69fadd8388d20a32c` |
| `_k70port_extract/qemu-fw/SILICIUM_UEFI-keys168.fd` | 4,194,304 B | `cef8dac15df4d0dca539c325b8baa93b1f0eec00738caf489d58d40cc30034ae` |

回退：`Mu-vermeer-keys167.img` = `49a6f8774f4e3fb523098b7cb12035b4ded6284bfdd7cebe2fe2e3da71e55cda`。
Menu EFI：27,136 B sha256 `3d0c586e1ceebca2841bca0cebbed2b18e427521a2cc8951ece1ccfe8bcf3132`；DtbExtn EFI 31,744 B。

## 2. 相对 keys167 的改动（2 个 DXE 模块，未新增模块、未动 PEI）

| 模块 | keys167 | keys168 | 改了什么 |
|---|---|---|---|
| VermeerMenuDxe | 27,710 B | 27,198 B | 删除 GOP 全屏填充与固定行坐标输出；改为 ConOut 路标行 + 20 ms Stall；不再 `CpuDeadLoop`；常驻事件循环（2 s alive / 5 s replug 重试）；SETUP 行改为短格式 |
| VermeerDtbExtnDxe | 31,300 B | 31,812 B | 驱动入口结尾追加一行 `[168] provider done`（ConOut + 20 ms Stall），bring-up 逻辑本身未改 |

SEC/PEI 65,440 B sha `cfcfca5e…` 与 keys167 **逐字节相同**；FVMAIN 内 90 个模块 0 增删；内嵌 DTB 808,716 B `71da2503…` 不变；容器内 kernel = gzip(192 B shim + FD)。离线核对：FVMAIN 中 17 个 `[168] …` 路标串均存在（UTF-16），`CpuDeadLoop` 出现 0 次。

## 3. 路标顺序（每行后 gBS->Stall(20000)，保证已进帧缓冲）

```
[168] provider done          <- VermeerDtbExtnDxe 入口末尾（APRIORI 第 4 位，最早）
[168] menu entered           <- Menu 入口，不再清屏
[168] init start
[168] dma done               <- AllocateMaxAddress(0xFFFFF000) 16 KiB 成功
[168] phy ready              <- GUSB2PHYCFG 清 SUSPHY/ENBLSLPM/PHYSOFTRST + 20 ms
[168] smmu bypass done       <- SMMU SID 0x40 bypass 流建立
[168] evt ring set           <- GEVNTADRHI/LO、SIZ=0x80001000、COUNT=0
[168] ep armed               <- DEPSTARTCFG / SETEPCONFIG / SETTRANSFRESOURCE / DALEPENA=3
[168] replug done            <- RUN_STOP off 150 ms -> on 150 ms
[168] ep0 armed              <- SETUP TRB 已排队
[168] init done
[168] loop start             <- 常驻循环开始
[168] alive evts=N           <- 每 2 s 一行；另有 [168] poll: cnt/DSTS/DCTL（每 2 s）
[168] setup bm=.. b=.. wv=.. wl=..   <- 每个 SETUP（<=60 字符）
[168] devaddr N              <- SET_ADDRESS
[168] replug retry           <- 每 5 s 强制 RUN_STOP off/on 并重新 arm SETUP TRB
```

**没有 GOP 清屏、没有 CpuDeadLoop、不返回 BDS**：控制台历史一路累积，黑屏问题消失；主机任何时刻重试枚举都能被接住（ep0 一直 armed）。

## 4. 上机只需拍最后 3 行 `[168]`

屏幕一路滚下去，拍照时**只要最后三行**即可判定停在哪一步：

| 最后看到的行 | 含义 / 下一步 |
|---|---|
| `[168] provider done` 后什么都没有 | provider 结束到 Menu 入口之间挂了（DxeCore 加载其它驱动 / SimpleFb 等）；看是否又黑屏 —— 但仍能定位到"Menu 没进" |
| `[168] menu entered` 后无 `[168] dma done` | AllocatePages(AllocateMaxAddress) 崩/挂 → 改回 AllocateAnyPages 或换地址再试 |
| `[168] dma done` 后停 | PHY/SMMU 访问处挂（最先怀疑 SMMU 基址访问或 CSD 内存属性）；看是否 `[168] phy ready` |
| `[168] phy ready` 后停 | SMMU bypass 写寄存器处挂 |
| `[168] smmu bypass done` / `evt ring set` 后停 | EP 配置 DEPCMD 挂 |
| `[168] ep0 armed` 后无 `loop start` | 从 arm 到循环之间（极少代码）—— 基本可判为中断/异常 |
| `[168] loop start` 后无 `alive` | 第一次 Poll/Stat 访问寄存器挂 |
| `alive` 正常、无 `setup` 行 | 事件环/上拉仍不通或主机没来枚举；每 5 s 的 `replug retry` 会一直重试 |
| 出现 `[168] setup …` | 主机在枚举、我们的 EP0 在工作 —— 按 bm/b 判读：`80 06`=取描述符、`00 05`=SET_ADDRESS、`00 09`=SET_CONFIGURATION |
| `setup` 后跟 `devaddr` / 且主机出现 `VID_1209&PID_0001` | 描述符被接受、地址已分配 —— 成功在望 |

## 5. 与 keys167 黑屏现象的关系

keys167 屏上最后一行是 `[VBUS] dec …`，随后全黑（GOP 填充黑）且无 `[167]` 行 → 说明 Menu 清屏之后、第一条 `[167]` 打印之前就出事（或首行打印本身失败）。keys168 对这一段的处理：
- 不再整屏填黑，保留旧文字；
- `[168] menu entered` 是 Menu 里第一条 ConOut 输出，若它出现说明清屏/首打问题消失，问题在初始化后段；若不出现，问题就在 Menu 入口到第一条打印之间（本版已无 GOP 调用，可疑点骤减）。
- 所有路标 20 ms 落屏，崩溃前最后一行一定可见。

## 6. 未改动 / 风险

- PEI（SEC/PEI）一字节未动；provider 早期 bring-up（VBUS/USB158 块）未改，只加末尾一行打印。
- 无 CSFTRST、无 QSCRATCH 写、无 GCC 读；SMMU bypass 与 replug 保留。
- 保持 EP0 应答器（keys167 的描述符/请求处理）不变：device 18 B（VID:PID 1209:0001）、config wTotalLength 18（单 vendor-specific 接口、0 端点）。
- 回退：`Mu-vermeer-keys167.img`（sha 见 §1），其现象为"全黑 + 主机看到 VID_0000&PID_0002"。
