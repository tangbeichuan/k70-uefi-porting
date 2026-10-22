# KEYS150 报告：DWC3 设备模式（PRTCAPDIR=2）修复 + 每行 ≤100 字符 dump

时间：2026-10-22 03:0x（Asia/Shanghai）
基线：lead 的 keys149（Menu 内嵌 USB149 诊断 + console halt，`Mu-vermeer-keys149.img`）
产物：keys150（仅改 VermeerMenuDxe 源码里的 USB 诊断块）

## 1. 产物

| 文件 | 大小 | sha256 |
|---|---|---|
| `K70-UEFI-build/Mu-vermeer-keys150.img` | 1,794,048 B | `72249c0b3e9cb1280c9b4134e049e58347ff57761647767ee06bdb106168d6e4` |
| `K70-UEFI-build/K70-keys150-DWC3-DEVICE.img`（副本） | 1,794,048 B | 同上 |
| `_k70port_extract/qemu-fw/SILICIUM_UEFI-keys150.fd` | 4,194,304 B | `22733b6e51124277cbd7301d6504a97a1755eedf22ed155d767bcd5e522db1bf` |

回退基线（keys149）：
`Mu-vermeer-keys149.img` sha256 `d8784724add3a60007cbd887eb719455b1144172667c7feaec224d8ade19f744`，
`SILICIUM_UEFI-keys149.fd` sha256 `fdc529e9f69f0f1c5b5b0d8667933aafef545f02a098e778f14ecdfb2d5693b`。

## 2. 改动（只改 `port-drivers/VermeerMenuDxe/VermeerMenuDxe.c`，构建时由 `patch_menu101.py` 拷进 pkg）

`_tools/patch_usb150.py` 把 lead 的 `Usb149Rd/Usb149Wr/Usb149LateDiag` 整块替换为 keys150 版：

1. `Usb150Dump(tag)`：一次读 8 个寄存器并输出 5 行（每行 ≤100 字符，防折行）：
   - `[USB150] tag id : GSNPSID GCTL GSTS`
   - `[USB150] tag cfg: GUSB2PHYCFG GUSB3PIPECTL DCFG`
   - `[USB150] tag dev: DCTL DSTS`
   - `[USB150] tag dec: prtcap run hlt22 spd lnk`（`prtcap=(GCTL>>12)&3`，`run=(DCTL>>31)&1`，
     `hlt22=(DSTS>>22)&1`，`spd=DSTS&7`，`lnk=(DSTS>>18)&0xF`）
   - `[USB150] tag phy: susphy enblslpm phyrst gsts_b0`
2. `Usb150LateDiag()` 顺序（按 lead 要求）：
   1) `GUSB2PHYCFG &= ~(SUSPHY(6) | ENBLSLPM(8) | PHYSOFTRST(31))`
   2) `GCTL.PRTCAPDIR = 2 (device)`（清 bit[13:12] 后置 `2<<12`），`Stall(100)`
   3) `DCTL.RUN_STOP = 1`
   4) 轮询 `DSTS.bit22 == 0` 最多 300×1 ms，再 `Stall(300 ms)`
   5) 幂等重放 VBUS override（QSCRATCH `0x0A6F8800`：`+0x10 |= (1<<20)|(1<<28)`、`+0x30 |= (1<<24)`），
      并打印 `[USB150] vbus: HS SS GCC_GDSCR(0x0010F004)`
   6) `[USB150] seq: PHYCFG GCTL DCTL polls=`，最后 `Usb150Dump("post")`
3. 保留 `CpuDeadLoop()`（拍照用）；`RunMenu()` 引用保留（`mGuiDisabled150 == 0` 分支，永不进入）。

> 只读 PHY：本版**没有**读 QUSB2(0x088E2000) 寄存器。原因：树内没有 QUSB2/GDSCR 权威位定义，
> 而 PHY 块若被 GCC collapse，读可能挂总线（会把整屏照片丢掉）。本版只打印 `GCC_USB30_PRIM_GDSCR`
> = `0x0010F004` 的原始值，下一版若需要再按 GDSCR 判定后读。

## 3. 对 keys149 真机数据的判读（含一处对 lead 结论的更正）

| 值（keys149 屏） | 判读 |
|---|---|
| `GSNPSID=55331310` | Synopsys USB3 core（`GSNPSID_MASK 0xFFFF0000 == 0x55330000`），IP revision `0x3130`；控制器基址 0x0A600000 读取正常 |
| `GCTL=00100201` | **`PRTCAPDIR(bits13:12)=0` → 当前不是 device 模式**；`PWRDNSCALE=2`；`DSBLCLKGTNG(bit0)=1`（比我方 keys148 读出时多置了 bit0，说明有代码写过 GCTL） |
| `PHYCFG=00102400` | `SUSPHY(6)=0`、`ENBLSLPM(8)=0`、`PHYSOFTRST(31)=0`，`USBTRDTIM=(>>10)&0xF=9`（UTMI 8-bit 推荐值）、`PHYIF(3)=0` ⇒ **USB2 PHY 侧本来就是正常态，keys149 的 PHYCFG 写是 no-op**，真正缺的只有 PRTCAPDIR |
| `DCTL=10F00000`（pre） | `RUN_STOP(31)=0`（未运行） |
| `DSTS=00D28CC4`（pre） | `bit22=0`（“未 halt”，与 DCTL.RUN_STOP=0 矛盾）、speed=`4`(SuperSpeed)、linkst=`(>>18)&0xF=4`(SS.Disabled) ⇒ **pre 时控制器其实还未被我们启动，DSTS 位域疑似读到了异常快照**，拍照值需复核 |
| `DCTL=90F00000`（run） | `RUN_STOP(31)=1` ✓ 写入生效 |
| `DSTS=00C9BBF4 hlt22=0`（run） | **矛盾**：`0x00C9BBF4 & (1<<22) != 0`（按位算 bit22=1），但屏上 `hlt22=0`。`polls=0` 只能说明“第一次读时 bit22==0”，不能证明写 RUN 之后状态才翻转。keys150 已把 pre/post 两行 dec 都打出来，可直接对照 |

**必须更正**：`DWC3_GCTL_PRTCAPDIR` 的 device 取值是 **2**，不是 1（1=host，2=device，3=OTG）。
依据（本机源码）：
- `/root/k70/uefi/Silicon/Samsung/SamsungPkg/Include/Device/Dwc3.h`：
  `DWC3_GCTL_PRTCAP_HOST 1 / DWC3_GCTL_PRTCAP_DEVICE 2 / DWC3_GCTL_PRTCAP_OTG 3`；
- 同树 `Silicon/Samsung/SamsungPkg/Drivers/UsbfnDwc3Dxe/Dwc3Core.c:243-244`：
  `Register &= ~DWC3_GCTL_PRTCAPDIR(DWC3_GCTL_PRTCAP_OTG); Register |= DWC3_GCTL_PRTCAPDIR(DWC3_GCTL_PRTCAP_DEVICE);`
- vendor 二进制（`Binaries/vermeer/QcomPkg/Drivers/UsbfnDwc3Dxe/UsbfnDwc3Dxe.efi`）0x3B48-0x3B64 一致：
  清 bit[13:12] 后 `orr w1,w8,#0x2000`（=2<<12）。
keys150 按 2 写，屏上 `GCTL` 预期从 `00100201` → `00102201`，`prtcap=2`。

关于 `GSTS`：本树 Samsung `Dwc3.h` 只给了 `DWC3_GSTS 0xC118`，没有位定义；vendor 的 UsbfnDwc3Dxe **完全不读 GSTS**
（全文件无 0xc118 引用）。Synopsys databook 中 GSTS[0]=`CSRTIMEOUT`（软复位超时），不是 connect 状态；
“有没有连上 host”应以 **DSTS**（speed/link state）+ Windows 侧枚举结果为准。keys150 仍打印 `gsts_b0` 供对照。
keys149 之前那次读到的 `GSTS=0x7E800000` 也很反常（高位全 1），大概率是“PHY/时钟未就绪时的非定义值”或拍照/误读，
这版 pre/post 都打，便于一次拍全。

## 4. 屏上应看到的行（keys150，按顺序，每行都能整行入镜）

```
[MENU150] console stays on, USB150 diag then photo halt
[USB150] pre  id: GSNPSID=55331310 GCTL=00100201 GSTS=........
[USB150] pre  cfg: PHYCFG=00102400 PIPECTL=........ DCFG=........
[USB150] pre  dev: DCTL=10F00000 DSTS=........
[USB150] pre  dec: prtcap=0 run=0 hlt22=? spd=? lnk=?
[USB150] pre  phy: susphy=0 enblslpm=0 phyrst=0 gsts_b0=?
[USB150] vbus: HS=........ SS=........ GCC_GDSCR=........
[USB150] seq: PHYCFG=00102400 GCTL=00102201 DCTL=90F00000 polls=?
[USB150] post id: GSNPSID=55331310 GCTL=00102201 GSTS=........   ← prtcap 变 2
[USB150] post cfg: PHYCFG=00102400 PIPECTL=........ DCFG=........
[USB150] post dev: DCTL=90F00000 DSTS=........
[USB150] post dec: prtcap=2 run=1 hlt22=? spd=? lnk=?             ← 关键行
[USB150] post phy: susphy=0 enblslpm=0 phyrst=0 gsts_b0=?
[MENU150] diag done - halting for photo
```

判据：
- `GCTL=00102201` / `prtcap=2` → 设备模式已生效；
- Windows 侧出现 **未知 USB 设备(VID_0000)** 或 `VID_1209` 即代表 **D+ 上拉已发生**（device 模式+RUN 生效）。
  即使 EP0 未重新初始化导致枚举失败（XBL 退出后事件缓冲/EP 状态可能已失效），host 也应至少看到“设备已连接”。
- 若 Windows 仍什么都没有：说明不是 PRTCAPDIR 的问题，下一步按 Samsung `Dwc3Core.c` 的完整
  `Dwc3CoreInit()` 顺序（GCTL device → 软复位 CSFTRST → PHY 设置 → 事件缓冲 → DCFG/DEVTEN/DALEPENA → EP0 → RUN）
  在 UEFI 侧重建整个 device 栈，而不是只补一个位。

## 5. 验证（离线）

- `Guid.xref`：AcpiTableDxe / UsbConfigDxe / UsbInitDxe / UsbMsdDxe / UsbfnDwc3Dxe / UsbDeviceDxe /
  VermeerPmicVerStubDxe / PmicDxe / VermeerDtbExtnDxe / VermeerLogDiskDxe / VermeerMenuDxe /
  ClockDxe / HALIOMMU 全在；UFSDxe=0。
- `FVMAIN.Fv` 6,156,288 B；`USB150` 宽字符命中 8 次、`MENU150` 2 次、`GSNPSID=`/`gsts_b0`/`GCC_GDSCR` 各 1 次；
  `USB149` 0 次（旧块已清除）。
- `UsbConfigDxe`（FD 内 FFS off=0x3CB728, size=86,170）：`0x3FA8=02000014`（强制 no-IOMMU 回退）、
  `0x53CC=280100b4`（keys145 NULL 守卫）、`0x3FEC=08b543f9`、`0x3FF0=080540f9` 保持原样。
- 内嵌 DTB 1 份，sha256 `78c55f2e08136cbfa4f8c2fdfaae66ce67306f7a65395536c4568e92213a3f56`，与源 `xbl_ufs.dtb` 逐字节相同。
- 构建后 `Binaries/.../UsbConfigDxe.patched.efi` 已由 restore trap 还原（0x3FA8 回到 `B6F80208`）。

构建脚本自身有一个**假警报**：`run_keys150.sh:32` 用 ASCII `grep "BlockIO devices"` 检查 Menu EFI，
但 Menu 的字符串是 UTF-16（`strings` 看不到），所以会打印 `MISSING BlockIO display` 并以 1 退出；
该退出码被 `bash run_keys150.sh | tail` 管道吞掉，构建本身成功（产物已验证）。下一轮可把该检查改成
`python3 -c "..."` 按 utf-16-le 统计，避免误导。

## 6. 回退

- keys150 有问题 → 直接刷回 keys149（`Mu-vermeer-keys149.img`，sha `d8784724…`）；
- keys149 的 Menu 代码不涉及 FV 布局/其它模块，keys150 同样只改 VermeerMenuDxe 一个模块的内容。
