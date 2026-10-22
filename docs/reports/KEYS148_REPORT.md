# keys148 — DWC3 寄存器偏移修正 + GSNPSID/GUSB2PHYCFG/DSTS dump（2026-10-22 02:50）

## 1. 产物

| 项 | 路径 | sha256 | 大小 |
|---|---|---|---|
| 镜像 | `/mnt/d/本地项目-01/K70-UEFI-build/Mu-vermeer-keys148.img` | `3355003674f643770c0aaf57ce3de957554e556d9defc317d651f402a13218ec` | 1,796,096 B |
| 镜像副本（可刷） | `/mnt/d/本地项目-01/K70-UEFI-build/K70-keys148-DWC3-FIX.img` | 同上 | 同上 |
| FD | `/mnt/d/本地项目-01/_k70port_extract/qemu-fw/SILICIUM_UEFI-keys148.fd` | `08144da9b1518f8f14daabdaf917119e950936d6cafeb5f86f95c5f91c298a42` | 4,194,304 B |
| 回退基线 keys147d | `Mu-vermeer-keys147d.img` | `22d1d32a9a75b34ca30f9f0e2f96415fa1eaa0f19806cea9314204f25ce35f2b` | 1,796,096 B |

构建血缘：`_tools/run148.sh` = `build_keys146.sh`/`run_keys146.sh` sed `keys146→keys148`（与 keys147d 完全同链：patch_usb126/130/pmicstub127/usb141/acpi142/usb143/clock144/usb145/usb146/fat137；NO_HAL 未设置，HALIOMMU 保留；patch_usb146 的 `0x3FA8=0x14000002` 强制 no-IOMMU 回退仍在）。**未新增 FV 模块**，布局与 keys147d 相同。

## 2. 根因：寄存器偏移错 4 字节（keys147c/147d 的 RUN_STOP 写错位置）

vendor 驱动（`UsbfnDwc3Dxe.efi` 反汇编，`_tools/k148_regs.txt` / `k148_u.txt`）与参考仓库
`_refs/ios-vermeer-lab/xnu/patches/0072,0073,0074` 一致给出：

| 寄存器 | 偏移 | 依据 |
|---|---|---|
| GCTL | 0xC110 | vendor 0x3B24 读后 `and #0xfffeffff`（清 bit16）、`and #0xffffcfff` 后 `orr #0x2000`（PRTCAPDIR=2=device）、`bfxil` 置 bit20 |
| GSTS | 0xC118 | 参考 0072 打印表 |
| GSNPSID | 0xC120 | vendor 0x38E8 读；Synopsys ID（期望 `0x5533xxxx`）|
| GUSB2PHYCFG | 0xC200 | vendor 0x38F8 `and #0xfffffeff`（清 bit8 ENBLSLPM）、0x3924 `and #0xffffffbf`（清 bit6 SUSPHY） |
| DCFG | 0xC700 | vendor 0x3B78 读后 `orr #0x400000`（bit22 LPM cap） |
| **DCTL** | **0xC704** | vendor 0x3824 `orr #0x40000000`（bit30 CSFTRST 软复位）+ 0xA874 轮询；0x60E0 `orr #0x80000000`（bit31 RUN_STOP）；0x4CA4 `and #0x7fffffff`（清 RUN_STOP） |
| DEVTEN | 0xC708 | vendor 0x3C1C 写 `0x1277` |
| **DSTS** | **0xC70C** | vendor 0x4CB4 用 mask `0x400000`（bit22）轮询 halt；0x4F78/0x9CD4/0x9E44 `DSTS & 7` 判 speed |
| DALEPENA | 0xC720 | vendor 0x3E58 写 3 |

keys147c/147d 的 [VBUS] 代码把 **0xC700 当 DCTL、0xC704 当 DSTS**：

```
keys147d: Dctl = *(0xC700); *(0xC700) = Dctl | (1<<31);   // 实际写进了 DCFG bit31（无意义）
          Dsts = *(0xC704);  hlt 用 (Dsts>>22)&1           // 实际读的是 DCTL bit22（与 halt 无关）
```

=> vendor 的 `DCTL(0xC704).RUN_STOP` 从来没被我们置位过；"hlt=1" 是错位读数（读到 DCTL 的 bit22）。keys148 已改正，并改成**不在早期强制 RUN_STOP**（避免与 vendor 的 core init 竞争），改由 LogDisk 在 BDS 之后"若仍 halted 才释放"。

## 3. lead 给的三行寄存器怎么读（按正确偏移重算）

| 旧打印 | 真实含义 | 解读 |
|---|---|---|
| `GCTL=0x00100200` | GCTL（偏移本来是对的） | bit20=1 → PWRDNSCALE[22:19]=2；**PRTCAPDIR[13:12]=0 → 该时刻 core 还没被配置成 device 模式**；bit16(U2RSTECN)=0；bit9 为 XBL 遗留 bit（vendor init 不清它） |
| `DCTL=0x004808D4` | 其实是 **DCFG** | DEVSPD[2:0]=4（SS capable）；DEVADDR[9:3]=26（XBL 遗留，SET_ADDRESS 会重写）；bit22=1（LPM cap，vendor init 也会 OR 这一位）；bit19 私有位；说明 XBL 碰过 DCFG，而我们的 UEFI 栈此刻还没配它 |
| `DSTS=0x10F00000` | 其实是 **DCTL** | **bit31 RUN_STOP=0 → 控制器 soft-disconnect、无 D+ 上拉**（这正是 host 看不到设备的直接原因）；bit30 CSFTRST=0；bit20~23、bit28 为 XBL 遗留的私有/低功耗字段 |
| `hlt=1` | 由 DCTL bit22 误算 | **无效**。真正 halt 标志是 DSTS(0xC70C).bit22；`(Dsts>>31)&1` 也不是 halted，是 DSTS 的 bit31 |

"控制器是否 detected/connected"只能从真 DSTS 读：`CONNECTSPD=DSTS[2:0]`、`USBLNKST=DSTS[21:18]`、`DEVCTRLHLT=DSTS[22]`。keys148 会在屏幕上直接打印这些。

## 4. PHY 结论（QUSB2 / eUSB2，GUSB2PHYCFG）

- 参考实现（`_refs/ios-vermeer-lab/USB-DEBUG.md`）明确：**驱动不改时钟、PHY/repeater、PMIC、SMMU**，只写 DWC3 设备寄存器 + QSCRATCH VBUS override；它在同一颗 SM8550 上枚举成功。PMIC 侧 eUSB2 repeater 已由 `UsbConfigDxe` 通过 SPMI 调好（真机日志 `usb_repeater_init, tuning_allowed: 1` + `WRITING: reg: 0xF051/0xFD54/0xFD57 res=0`）。
- 因此 keys148 采用的"最小 PHY 动作"= 参考序列等价物：QSCRATCH VBUS override → `GUSB2PHYCFG.SUSPHY(bit6)=0`、`ENBLSLPM(bit8)=0` → `DCTL.RUN_STOP=1`；执行点放在 **LogDisk 的 2 s 定时器**（BDS 已把所有 USB 驱动加载完），且**仅在 `DCTL.RUN_STOP==0` 或 `DSTS.DEVCTRLHLT==1` 时才动手**（否则只打印，不干预 vendor）。
- 期望 `GUSB2PHYCFG(0xC200)` 初始化后：bit6=0、bit8=0，其余（PHYIF/ULPI_UTMI_SEL/30MHZ 等）保持 XBL 值；keys148 打印原始值与 SUSPHY/ENBLSLPM 位。
- 若后续真机证明 PHY 真没起来：下一步只做**只读**诊断——先读 GCC `USB30_PRIM_GDSCR(0x0010F004).bit31`（1=power on），再读 QUSB2 PHY(0x088E2000，size 0x400：PLL_STATUS 0x1A0 / PWR_CTRL1 0x210 / PORT_TUNE1 0x240 / TEST1 0x254)；**不要从 UEFI 直接写 PHY 寄存器**（PHY 时钟被门控时会挂死总线）。

## 5. DT 结论

**不需要补任何节点/属性。**
- `/soc/usb0/hs_phy_cfg/table` = `<0xffffffff 0 0xffffffff 0 …>` 是厂商约定的"**不覆盖**哨兵表"（参考 0072 只读、不写 PHY；vendor 代码对 HS PHY 也不按表写），所以它是正常值，不是缺失。
- `/soc/usb0/ss_phy_cfg/table` 是 QMP combo PHY（0x088E8xxx/0x088E9000）的 (addr,value) 序列，只与 USB3/DP 超高速相关；USB2 枚举不需要它。
- `/soc/usb0` 本身没有 `reg`（DWC3 基址 0x0A600000 在 vendor 代码里写死），也没有 `qcom,dwc3`/`snps,dwc3` 兼容串需求。
- DTB 在 FV 内与 `xbl_ufs.dtb` 逐字节相同（57,217 B，sha256 `78c55f2e08136cbfa4f8c2fdfaae66ce67306f7a65395536c4568e92213a3f56`，1 份 @FVMAIN 0x3FFCAC）。

## 6. keys148 代码改动

1. `port-drivers/VermeerDtbExtnDxe/VermeerDtbExtnDxe.c`（APRIORI 第 4 位，早期）：VBUS override 保留；**寄存器全部改用正确偏移**，dump 变成：
   `[VBUS] before: GSNPSID=.. GCTL=.. GSTS=.. GUSB2PHYCFG=.. DCFG=.. DCTL=.. DEVTEN=.. DSTS=..`
   `[VBUS] scratch: GEN=.. HS=.. SS=..`
   `[VBUS] after : HS=.. SS=.. GUSB2PHYCFG=.. DCFG=.. DCTL=.. DSTS=..`
   `[VBUS] dec   : run_stop=.. csfrst=.. phy_susphy=.. phy_enblslpm=.. hlt22=.. speed=.. linkst=..`
   早期**不再**写 GUSB2PHYCFG/DCTL（避免抢 vendor 的 core init）。
2. `_tools/VermeerLogDiskDxe.c`（构建源，BDS 后 2 s 定时器）：新增
   `UsbDiagDumpDwc3(tag)`（正确偏移的 8 寄存器 dump + 解码：run_stop/csfrst/phy_susphy/hlt22/hlt31/speed/linkst/sssts）与
   `UsbDiagEnsureRun()`（若 halted：清 SUSPHY/ENBLSLPM → 置 RUN_STOP → 轮询 200×1 ms 等 `DSTS.DEVCTRLHLT` 清）。
   打印点：`[USBDIAG] DWC3[probe]`、`[USBDIAG] DWC3 late run`、`[USBDIAG] DWC3[post-run]`、ConnectController 后 `[USBDIAG] DWC3[post-connect]`。
   原有 `QcomUsbConfig` iface+0x88/+0x8c、`LocateProtocol(UsbFnIo)`、`LocateHandleBuffer` 计数、逐句柄 ConnectController 诊断全部保留。

## 7. 离线验证（全部通过）

- FD/img/副本 sha 见上；镜像 1,796,096 B（与 keys147d 同布局）。
- `cf146d.py` 解 FD→FV→PE：HALIOMMUDxe/ClockDxe 都在；UsbConfigDxe FFS 86,170 B，`0x3FA8=02000014`（`b 0x3fb0` 强制 no-IOMMU 回退）、`0x53CC=280100b4`（反初始化 NULL 守卫）、`0x3FEC/0x3FF0` 原样。
- `FVMAIN.Fv` 6,164,480 B；新字符串命中：`GSNPSID=` ×2、`[VBUS] dec` ×1、`phy_susphy` ×2、`DWC3 late run` ×1、`probe end` ×2、`run_stop=` ×2；内嵌 DTB 1 份且 sha 与源 dtb 相同。
- Guid.xref：UsbConfigDxe/UsbInitDxe/UsbMsdDxe/UsbfnDwc3Dxe/HALIOMMU/ClockDxe/AcpiTableDxe/PmicDxe/VermeerDtbExtnDxe/VermeerLogDiskDxe/VermeerMenuDxe 全在；UFSDxe 0。
- 构建后源码树 restore trap 生效：`UsbConfigDxe.patched.efi` 回到 pristine（`0x3FA8=0802f8b6`、`0x53CC=080540f9`）。

## 8. 下次真机要看哪几行 / 判定表

| 屏幕行 | 判据 |
|---|---|
| `[VBUS] before: GSNPSID=` | 若 `5533xxxx` → DWC3 基址/偏移正确，映射确认；否则基址不对 |
| `[VBUS] dec: run_stop=0 hlt22=1` | 早期（vendor 之前）控制器确实 halted、无 D+ 上拉 |
| `[USBDIAG] DWC3[probe] ... DCTL=... DSTS=...` | BDS 后真实状态：`DCTL.bit31`、`DSTS.bit22/bit[2:0]/bit[21:18]` |
| `[USBDIAG] DWC3 late run: DCTL=.. DSTS=.. polls=.. hlt22=..` | 若 hlt22 变 0 → 控制器已运行；若仍 1 → core 拒绝运行（时钟/PHY/reset 状态问题） |
| `[USBDIAG] UsbFnIo=Success` | 唯一硬判据：vendor 的 DriverBinding.Start 成功、gEfiUsbFunctionIoProtocolGuid 已安装 |
| `[USBDIAG] DWC3[post-connect] ... speed=/linkst=` | speed≠0 或 linkst 变化 ⇒ PHY 已把线状态给到 core；host 侧应出现设备 |

如果 `late run` 后 hlt22=0 但 host 仍无设备：下一步查 PHY/时钟（GCC GDSCR/CBCR 只读 + QUSB2 只读），并考虑把 RUN_STOP 放到 vendor `UsbConfigDxe`/`UsbfnDwc3Dxe` 之后更贴近 vendor 时序的位置（当前已是最晚的 DXE 阶段）。
