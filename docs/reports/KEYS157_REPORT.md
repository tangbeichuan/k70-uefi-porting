# keys157 报告：DWC3 bring-up 前移 + Menu 只读常驻（枚举窗口）

日期：2026-10-22
任务来源：lead m03530（`VID_0000&PID_0002`/描述符请求失败 = D+ 已拉起、缺 EP0 应答；要求 bring-up 前移到厂商 USB 栈之前、Menu 恢复常驻）
基线：keys156（keys154 血缘）

---

## 1. 改动一：早期 DWC3 device-mode bring-up（核心）

**位置**：`VermeerDtbExtnDxeEntry()` 末尾，keys148 `[VBUS]` 块之后、`return EFI_SUCCESS` 之前。
**为什么是这个模块**：`Include/APRIORI.inc:4` = `INF vermeerPkg/Drivers/VermeerDtbExtnDxe/VermeerDtbExtnDxe.inf`，比所有厂商 USB 驱动都早（:169 UsbMsdDxe、:174 UsbConfigDxe、:175 UsbInitDxe，UsbfnDwc3/UsbDevice 由 patch 插在 Menu 前）。DWC3/QSCRATCH 的 MMIO 区域在 `MemoryMapLib` 的 `USB 0x0A600000 +0x00200000` 里，PEI/DXE 都已映射，所以这里可以安全访问。

**写的寄存器（与真机验证过的 keys154 完全一致）**：
```
GUSB2PHYCFG (0x0A60C200) &= ~(SUSPHY(bit6) | ENBLSLPM(bit8) | PHYSOFTRST(bit31))
DCTL        (0x0A60C704) |= RUN_STOP(bit31)
poll DSTS.DEVCTRLHLT (0x0A60C70C bit22) == 0，最多 300 × 1 ms
```
- 若 `DCTL.RUN_STOP` 已是 1 则打印 already running、不写；
- **不碰 DEVTEN/GEVNT/EP0**：事件缓冲归厂商 `UsbfnDwc3Dxe` 所有，提前开 `DEVTEN=0xF` 而 GEVNTADR 仍为 0 时，设备事件可能让控制器写地址 0（AXI 风险），所以本版只把控制器跑起来，事件/中断交给厂商栈；
- 打印：`[USB157] early pre : GCTL/PHYCFG/DCTL/DEVTEN/DSTS`、`[USB157] early run : polls=… PHYCFG/DCTL/DSTS hlt22 run`（反汇编已确认上述 mask/写/轮询全部编入，见 §4）。

## 2. 改动二：Menu 变成只读常驻监视器

`patch_usb157.py`（从 pristine keys149 Menu 一次性生成，替换掉 keys152/154/156 的整条菜单补丁链）：
- **不做任何 USB/QSCRATCH/GCC 写**：`Usb157Dump()` 只 `ldr`（GSNPSID/GCTL/PHYCFG/DCTL/DEVTEN/DSTS + QSCRATCH HS/SS），**绝不读 GCC**（keys152 就是崩在 GCC 0x0010F004 未映射上）；
- **常驻循环**：`for (;;) { 每 50 tick 打一次 [USB157] alive；ReadKeyStroke；gBS->Stall(100000) }`，10 ms→100 ms 粒度，每 ~5 s 一行心跳；
- 按键后离开循环 → `RunMenu()`（原厂文字 UI，常驻，不返回 BDS）⇒ 手机不会因为 BDS 找不到启动项而 `ResetSystem(shutdown)`，主机可以长时间枚举；
- `ForceLoadSimpleFb` 仍是 stub（不 LoadImage/StartImage）；
- 无 `CpuDeadLoop`。
- 注意：源码里第三行 `[MENU157] done, returning to BDS` 在编译时被当作不可达删除（`RunMenu()` 不返回），所以二进制里 `MENU157` 出现 2 次、`CpuDeadLoop` 0 次 —— 行为符合预期。

## 3. 产物

| 项 | 文件 | sha256 | 大小 |
|---|---|---|---|
| img | `K70-UEFI-build/Mu-vermeer-keys157.img` = `K70-keys157-EARLY-USB-RUN.img` = `-fat.img` | `8ddc2f588bff0d62a7966aa58b26c3d141cd4b71797327f7df91052f8b633756` | 1,798,144 |
| FD | `_k70port_extract/qemu-fw/SILICIUM_UEFI-keys157.fd` | `0e39c250ab87444954ccd1d54b2a28d2e6fa89686992a77851db41015a9f3db5` | 4,194,304 |
| 附 | `Mu-vermeer-keys157-v4.img` | `f165cfe593b3b576640f23b91b76540e962dbf0058e41dba47b6e40fbd452636` | — |

回退：keys156 img `9185fc59675e0c756c241251e643ee93a412312a64c55b22aa135cec39643ddb`。

## 4. 离线验证（verify157.py）

- **模块 diff vs keys156：89/89、0 增删、恰好 2 个变化**：
  - `VermeerMenuDxe` 20,566 → 29,270（现在直接调用 RunMenu，整套 UI 不再被死代码消除）
  - `VermeerDtbExtnDxe` 30,812 → 31,324
- **SEC/PEI 与 keys156 逐字节相同**（`cfcfca5e…`，GCC 区域名 0）⇒ 未动 PEI。
- 容器：解压 = 0xC0 shim + FD 4,194,304 与 FD 文件一致；尾随 DTB 808,716 B sha `71da2503…` 不变。
- Menu EFI 29,184 B：UTF-16 `MENU157`×2 / `USB157`×2 / `UI157`×1 / `CpuDeadLoop` 0；反汇编 **GCC 立即数 0 条、USB/QSCRATCH store 0 条**；`Stall(100000)` = `mov w0,#0x86a0; movk w0,#0x1,lsl#16` 存在；循环体有 `ReadKeyStroke`（`ldr x8,[x0,#8]; blr`）。
- DtbExtn EFI 31,232 B：ASCII `USB157`×3、`[VBUS]`×4；关键反汇编：
  ```
  21dc ldr w2,[x23,#-0xf0]     ; GCTL   (x23 = 0x0A60C200)
  21e0 ldr w20,[x23]           ; PHYCFG
  21ec ldr w19,[x23,#0x504]    ; DCTL
  21f0 ldr w5,[x23,#0x508]     ; DEVTEN
  21f4 ldr w6,[x23,#0x50c]     ; DSTS
  ...  DebugPrint "[USB157] early pre"
  2204 tbnz w19,#0x1f, 0x228c  ; 已 RUN_STOP -> 跳过
  2208 mov w8,#0xfebf / movk w8,#0x7fff   ; mask = ~(bit31|bit8|bit6)
  2214 str w8,[x23]            ; PHYCFG &= ~(SUSPHY|ENBLSLPM|PHYSOFTRST)
  221c orr w8,w19,#0x80000000
  2220 str w8,[x23,#0x504]     ; DCTL |= RUN_STOP
  2228.. 轮询 up to 300 次: ldr DSTS; tbz bit22 -> 成功; gBS->Stall(1000)
  ...  DebugPrint "[USB157] early run : polls=…"
  ```

## 5. 上机判读

启动顺序预期：
```
[MENU154] ...（Menu 触发的旧打印不会再有；Menu 现在只打 [USB157]）
[DTBEXTN] protocol installed ...          ← DtbExtn（APRIORI 4）
[USB157] early pre : GCTL=… PHYCFG=… DCTL=… DEVTEN=… DSTS=…
[USB157] early run : polls=… PHYCFG=… DCTL=… DSTS=… hlt22=0 run=1
... Loading driver … UsbConfigDxe / UsbInitDxe / UsbfnDwc3Dxe / UsbDeviceDxe / UsbMsdDxe
... Loading driver … VermeerMenuDxe
[MENU157] resident loop: USB device-mode already running early; staying enumerated
[USB157] entry: GSNPSID=… GCTL=… PHYCFG=… DCTL=… DEVTEN=… DSTS=…
[USB157] entry: run=1 hlt22=0 spd=… lnk=… prtcap=2 HS=… SS=…
[USB157] alive: …（每 ~5 s 一行）
```

| 现象 | 结论 / 下一步 |
|---|---|
| 主机出现 `VID_1209`/`VID_2717`/Mass Storage/COM | 厂商 gadget 栈接管成功 |
| 仍 `VID_0000&PID_0002`，但 `[USB157] early run hlt22=0 run=1` | 控制器在跑但厂商栈没接管 EP0 ⇒ 查 `UsbConfigDxe/UsbInitDxe/UsbfnDwc3Dxe` 的 Start 失败点（下一步：给它们补 DEBUG，或显式 `ConnectController`），必要时 keys158 走最小 DEVTEN/EP0 gadget |
| `early run` 显示 `hlt22=1`（300 次轮询后仍 halt） | core 没起来 ⇒ 时钟/PHY 侧问题，回到 GCC GDSCR/CBCR 方向（keys155 的只读读数） |
| 一行 `[USB157]` 都没有 | DtbExtn 没跑 / USB 区域未映射 ⇒ 查 APRIORI 与 MemoryMapLib |
| 常驻循环里反复 reboot | USB 运行态中断风暴 ⇒ keys158 加 `DEVTEN=0` 或屏蔽 GIC USB IRQ 做对照 |

本版不做 EP0 应答；若厂商栈不接管，枚举仍失败（与 keys154 一样只能看到 DWC3 连接态）。

## 6. 源码/脚本

- `_k70port_extract/port-drivers/VermeerDtbExtnDxe/VermeerDtbExtnDxe.c`：`VermeerDtbExtnDxeEntry` 末尾新增 keys157 早期 bring-up 块（约 2120-2200 行）。
- `_tools/patch_usb157.py`（Menu → 只读常驻；幂等锚 `[MENU157]`）、`_tools/run157.sh`（keys156 血缘 → keys157，菜单链替换为 patch_usb157）、`_tools/verify157.py`。
- 构建脚本：`_k70port_extract/wsl/build_keys157.sh`；日志 `_tools/b157_wrap.log`、`/tmp/keys157-build.log`。
