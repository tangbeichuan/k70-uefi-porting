# keys164 交付报告 —— EP0 原始事件追踪（清屏 + 8 s 停机）

日期：2026-10-22
基线 = **keys161**（最小 EP0 gadget，不碰 CSFTRST，PHY 保活）
本次唯一改动：**VermeerMenuDxe（Menu）**。SEC/PEI 与其它 89 个模块逐字节未动（SEC sha `cfcfca5e…` 与 keys161 相同）。

---

## 1. 产物与 sha256

| 文件 | 大小 | sha256 |
|---|---|---|
| `K70-UEFI-build/K70-keys164-EP0-TRACE-HALT.img` | 1,796,096 B | `493211b646e9d086fb5106fdc5e5f7bc75e757c9dd7ffb5220420cc98a40afe3` |
| `K70-UEFI-build/Mu-vermeer-keys164.img`（= `-fat` = `-marker`） | 1,796,096 B | 同上 |
| `_k70port_extract/qemu-fw/SILICIUM_UEFI-keys164.fd` | 4,194,304 B | `c50936d56706e9938decc48419ecbdd6e9dd96e9b940756c08ddb33cb10ad7eb` |
| `K70-UEFI-build/Mu-vermeer-keys164-v4.img` | — | `601328d27e517895f41d134f2db28e58d61ce37be9b2567f3e2e4209856693aa` |
| Menu EFI（构建目录） | 25,088 B | `981f34edecb6c7f5a85500f572f052f5519b6dd21f6914a94420ebd246218042` |

回退（当前 boot_a 里的 keys162）：`Mu-vermeer-keys162.img` = `c3204d4763c1ad661ca83a7db2663c2b2f34b5515ea6cf016e2d09df6e02f99a`。

---

## 2. 相对 keys161 的差异（离线验证 PASS）

| 检查项 | 结果 |
|---|---|
| SEC/PEI | 65,440 B，sha `cfcfca5e…`，与 keys161 **逐字节相同** |
| inner FVMAIN | 6,160,392 B；90 模块、**0 增 0 删**，唯一变化 Menu（`4f7a1c2e…`）：34,366 → 25,150 B |
| 容器 | `ANDROID!` v1、page 2048、kernel 1,790,811 B = gzip(192 B shim + FD)、解压 4,194,496 B、img 内 FD == FD 文件 |
| 尾随 DTB | 808,716 B，sha `71da250370a977dacc230bd7977ff43f397e388bf02a55c162b22662152c3891`（与 keys149/152/161/162 相同） |
| Menu 串（UTF-16） | `MENU164`、`[164] evt raw=`、`[164] dep evt raw=`、`[164] poll`、`[164] regs:`、`[164] done: evts=`、`[164] dep n=` 全部在 |
| 反汇编 | `mov w24,#0xc704`(DCTL)、`mov w8,#0xc800`(DEPCMD 基址)、`mov w22,#0xc700`(DCFG) 都在；**GCC 0x0F004 立即数 0 处**；自跳转（CpuDeadLoop）存在；无 QSCRATCH 地址串 |
| EP0 arm 顺序（源码） | `DEPSTARTCFG(9) → SETEPCONFIG(ep0out/ep0in, mps=512) → SETTRANSFRESOURCE ×2 → DALEPENA=0x3 → RUN_STOP 保活（已 run 不写） → arm SETUP TRB` |

---

## 3. 屏上会看到什么（预期格式）

```
  [MENU164] keys164 EP0 trace: raw events only, 8 s then CpuDeadLoop
  [164] dma=00000000C6... (16 KiB)
  [164] phycfg=00102400 gctl=00100200 dctl=80F....
  [164] evt: addr=00000000C6... siz=00001000 cnt=00000000
  [164] dep n=0 cmd=09 ok=1 st=0          ← DEPSTARTCFG
  [164] dep n=0 cmd=01 ok=1 st=0          ← SETEPCONFIG(ep0 out)
  [164] dep n=0 cmd=02 ok=1 st=0          ← SETTRANSFRESOURCE(ep0 out)
  [164] dep n=1 cmd=01 ok=1 st=0          ← SETEPCONFIG(ep0 in)
  [164] dep n=1 cmd=02 ok=1 st=0          ← SETTRANSFRESOURCE(ep0 in)
  [164] dep n=0 cmd=06 ok=1 st=0          ← arm SETUP TRB（STARTTRANSFER）
  [164] gadget up: GSNPSID=55331310 ...   up2: DALEPENA=00000003 DSTS=...
  [164] bringup done: hlt22=0 phycfg_bit6=0 devspd=1
  [164] evt raw=XXXXXXXX                  ← 每条事件原样（最多 16 条）
  [164] dep evt raw=XXXXXXXX              ← 端点类事件额外一行
  [164] dep n=0 cmd=01 ok=1 st=0          ← SETUP 收到后重新 SETEPCONFIG(mps 64)
  [164] poll: cnt=00000000 DSTS=00xxxxxx DCTL=80xxxxxx   ← 每秒
  [164] regs: GCTL=... PHYCFG=... DEVTEN=00000007 SIZ=00001000  ← 值变化时
  [164] done: evts=NN bytes=NNNN hlt22=0 DSTS=XXXXXXXX   ← 8 s（或 16 条事件）后
```
之后 `CpuDeadLoop()`，屏幕定格，不会再被 PEI/DXE 的 `Memory Allocation` 输出冲掉。

---

## 4. raw 值 → 事件类型对照表

译码与本地参考实现（`_refs/ios-vermeer-lab/xnu/patches/0073-sweet-usb-device-ep0.patch`，**同一颗 DWC3、真机枚举成功**）一致：

**A. 设备事件（`raw & 1 == 1`）** —— `event_type = (raw >> 8) & 0xF`

| event_type | 含义 | raw 典型形态 |
|---|---|---|
| 0 | Disconnect | `0x??????01`（bits8-11=0） |
| 1 | **USB Reset** | `0x????0101` 附近 |
| 2 | **Connect Done** | `0x????0201` 附近 |
| 3 | Link State Change | `0x????0301` 附近 |
| 其它 | 保留/厂商 | 记录即可 |

**B. 端点事件（`raw & 1 == 0`）** —— `ep = (raw >> 1) & 0x1F`、`type = (raw >> 6) & 0xF`、`status = (raw >> 12) & 0xF`

| type | 含义 | 说明 |
|---|---|---|
| 1 | **XferComplete** | SETUP 完成（ep=0）、数据/状态阶段完成 |
| 2 | XferInProgress | 一般不用 |
| 3 | **XferNotReady** | 控制状态阶段：`status=2`（control status） |
| 其它 | 保留 | — |

**SETUP 到底以什么形式出现**：keys161/keys164 的 EP0 状态机同时处理
- `type==1 (XferComplete)` 且 `ep==0` → 读 8 字节 SETUP，回描述符；
- `type==3 (XferNotReady)` 且 `status==2` → 起状态阶段 TRB。
所以 raw 一出现，按上表即可判定；若只出现 `type=3,status=2` 而从不出现 `type=1,ep=0`，说明 SETUP 被 EP0 的 arm 方式吃掉/未被控制器接受。

**常见 raw 参考值（对照用）**
- `0x00000201`：connect done（bits8-11=2）→ 表明 D+ 已在总线上完成连接协商；
- `0x00000101`：USB reset；
- `0x00000001`：disconnect；
- `0x00000021` 附近：ep0 OUT XferNotReady（status 见 bits12-15）。

> 注：以上位段与 keys162/163 里打印的解析一致；本次只打原始 raw，最终以上机 raw 为准。

---

## 5. 每个 DEPCMD 的判读

`[164] dep n=%u cmd=%02x ok=%u st=%x`
- `cmd`：09=DEPSTARTCFG、01=SETEPCONFIG、02=SETTRANSFRESOURCE、06=STARTTRANSFER、04=SETSTALL；
- `ok=1` 表示 CMDACT 已清零且**状态码 st=0**（命令被控制器接受）；`ok=0` 则 `st` 是 DWC3 返回的非 0 状态（重点记录）；
- 如果 `cmd=01/02` 全部 `ok=1`，而 arm SETUP (`cmd=06`) 也 `ok=1`，则 EP0 已就绪，等主机 SETUP。

---

## 6. 上机判读决策树

1. **看到 `[164] evt raw=`（尤其 `…0201` connect done / `…0101` reset）** → 事件环与连接都正常，继续看是否出现 `[164] dep evt raw=`（端点事件）：
   - 有端点事件后出现 `dep n=0 cmd=01`（重新 SETEPCONFIG 64B）→ 我们已经收到 SETUP 并在应答，主机应能拿到描述符；
   - 只有 `XferNotReady` 没有 `XferComplete` → arm/TRB 时序问题，下一包 keys165 把 arm 移到 connect-done 之后（参考实现就是 connect-done 时才 SETEPCONFIG 512→64）。
2. **一条 `[164] evt raw=` 都没有，但 `dep` 行全部 `ok=1`** → 事件环本身没收到事件（DMA 不可见 / 事件未使能）。下一包 keys165：按 vendor 顺序 **HI→LO**、`DEVTEN=0x1277`、并在 RUN 之后再清一次 GEVNTCOUNT；也可以把事件环地址改成 32 位对齐且关闭 SMMU（HAL IOMMU 已放回 FV，若 IOMMU 把 EP0 缓冲映射成不可写，会表现为“无事件”）。
3. **`dep` 行出现 `ok=0 st≠0`** → 直接按命令号定位（SETEPCONFIG 失败通常是 ep0 已被占用或 DALEPENA 未置；STARTTRANSFER 失败通常是 TRB 物理地址不合法）。
4. **设备在 8 s 内被主机判为“未知 USB 设备”且屏上已有 `evt raw`** → EP0 应答内容问题（描述符），下一包按 raw 定向修。

---

## 7. 备注

- keys164 在 8 s 后 `CpuDeadLoop()` 停机，**停机后不再轮询事件**（这是为了保住屏幕 trace）；如果需要在停机后仍能枚举，keys165 会把 halt 改成“延时后继续轮询”。
- 本包不含任何 CSC/CSFTRST/QSCRATCH/GCC 访问；EP0 描述符：VID `0x1209`、PID `0xC101`、1 配置 1 接口 0 端点、字符串 "Vermeer" / "K70 UEFI DEBUG"。
- 构建可复现；本包与 keys161 的唯一模块差异即 Menu（见 §2）。
