# keys154 报告 — Menu 崩溃修复 + USB device-mode bring-up

生成时间：2026-10-22（Asia/Shanghai）· 基线：keys152（== keys149 + 最小 Menu）
交付：`Mu-vermeer-keys154.img`、`K70-keys154-USB-RUN.img`、`SILICIUM_UEFI-keys154.fd`

---

## 0. 结论摘要

| 项 | 结果 |
|---|---|
| keys152 崩溃根因 | Menu 读 **GCC_GDSCR（0x0010F004）**，该地址在 DXE 页表**未映射** → data abort，PC=FAR 同为 0x0010F004 附近 |
| 修复 | 删除全部 GCC 读取；Menu 只读已映射的 DWC3（`0x0A600000`）与 QSCRATCH（`0x0A6F8800`）窗口 |
| keys154 Menu 动作 | `[USB150] pre` 只读 dump → `[USB154] vbus readonly`（只读 QSCRATCH+0x10/+0x30）→ `GUSB2PHYCFG` 清 SUSPHY/ENBLSLPM/PHYSOFTRST（读回校验）→ `DCTL.RUN_STOP=1`（读回校验）→ `gBS->Stall(50ms)`×2 + 中间 DSTS 打印 → `[USB150] final` dump → `Say("[USB154] after-run: done")` → `return EFI_SUCCESS` |
| 不写 | **不写 QSCRATCH**（VBUS 覆盖一律不做）；不写 GCTL（prtcap 已是 2=device）；不读 GCC；无 `CpuDeadLoop` |
| PEI | 与 keys149/keys152 **逐字节相同**（SEC/PEI FFS body sha `cfcfca5e…`） |
| 与 keys152 的差异 | **仅 VermeerMenuDxe 一个模块 body**（大小同为 20,054 B，sha `fd27b1f3…` → `f5a76ab1…`） |

---

## 1. 产物

| 文件 | SHA-256 | 大小 |
|---|---|---|
| `_k70port_extract/qemu-fw/SILICIUM_UEFI-keys154.fd` | `1ed89cd31eb0103e5393763c6b52ed0e96f4022bf93329cd7659ff9f20bfd1b4` | 4,194,304 B |
| `K70-UEFI-build/Mu-vermeer-keys154.img` | `37cce641682af39f6abc2a7ddcd7d9aee49094cd1c9eadca5a47b42c36921155` | 1,794,048 B |
| `K70-UEFI-build/K70-keys154-USB-RUN.img` | 同上（复制） | 1,794,048 B |

基线 keys152：img `0f0be4f2f3148192710893206a78ab0984dda1c2641db5c4f71c486bc9fff942`、FD `1cc799f1c04b06d140b2316636f16052ec6cd27010184e3aaf68f480e72dcbfa`。

**与 keys152 的 diff（离线全量）**

* FD：90 模块 / 0 增删；**唯一变化 `4f7a1c2e-93b5-4d68-a1e7-6c2b8f5d3a90 VermeerMenuDxe`**（20,054 → 20,054 B，sha `fd27b1f3…` → `f5a76ab1…`）。
* SEC/PEI FFS body：`cfcfca5efb6b80fe4328d04a915ac44c476387d55b3df9063f4af7b083282fdc`（两版相同）。
* inner FVMAIN 长度：6,156,296 B（两版相同）。
* 容器：`ANDROID!` v1、page 0x800、kernel=gzip(shim 192 B + FD 4,194,304 B) 解压 4,194,496 B；**img 内 FD 与 FD 文件逐字节一致**；尾部 DTB 808,716 B sha `71da2503…`（与 keys152 相同）。

---

## 2. 崩溃根因（keys152，Menu +0x1C98）

真机：`Synchronous Exception at 0x0000000C61B9C98`，`PC 0xC61B9C98 (0xC61B8000+0x1C98)`，`X1=0 X2=0xC61BCCD0 X4=1`，且已打印完 `[USB150] pre` 的 5 行。

**定位**：`VermeerMenuDxe.map` 中 `_ModuleEntryPoint` = 0x1AEC…0x1D00 ⇒ RVA 0x1C98 位于 entry 函数体内。反汇编 0x1C80–0x1CA0：

```asm
1c80  mov  w8, #0xf004
1c84  movk w8, #0x10, lsl #16      ; x8 = 0x0010F004  (GCC_GDSCR)
1c88  ...                           ; x9 = 0x0A6F8810 (QSCRATCH+0x10)
1c8c  ldr  w9,  [x9]                ; QSCRATCH+0x10  (mapped)
1c90  ldr  w4,  [x9, #0x20]         ; QSCRATCH+0x30  (mapped)
1c98  ldr  w5,  [x8]                ; ★ GCC_GDSCR —— NOT mapped -> data abort
1c9c  adrp x2, 0x4000 ; add x2, ... ; fmt = "[USB152] vbus readonly: HS=%08x SS=%08x GCC_GDSCR=%08x"
1cac  bl   UnicodeSPrint
1cb4  bl   Say
```

**结论**：DWC3（0x0A600000）与 QSCRATCH（0x0A6F8800）在 0x0A600000 起的 2 MiB 已映射窗口内（所以 pre dump 的 5 行都打印成功），但 **GCC（0x0010F004）不在 DXE 映射里**，读它即 fault。`X1=0`/`X4=1` 是 `UnicodeSPrint` 的参数残留，与函数指针/Stall 无关。

> 附带校正：真机照片里的 `ICFG=00480B84` 实为 `DCFG=00480B84`（源码与 EFI 的 UTF-16 都只有 `DCFG`）。

---

## 3. keys154 Menu 实现（`port-drivers/VermeerMenuDxe/VermeerMenuDxe.c` → pkg 副本，`patch_usb154.py`）

```text
[MENU154] USB device-mode bring-up: pre-dump, PHYCFG/DCTL writes, no QSCRATCH
  Usb150Dump("pre ")                       ; 只读：GSNPSID/GCTL/GSTS/PHYCFG/PIPECTL/DCFG/DCTL/DSTS
  [USB154] vbus readonly: HS/SS            ; 只读 QSCRATCH+0x10 / +0x30（不写、不读 GCC）
  [USB154] phycfg: before/want/after/ok    ; GUSB2PHYCFG &= ~(SUSPHY|ENBLSLPM|PHYSOFTRST)
  [USB154] dctl: before/after/run          ; DCTL.RUN_STOP=1（读回校验）
  [USB154] after-run[0/1]: DSTS hlt22 spd lnk   ; gBS->Stall(50ms) ×2，中间读 DSTS
  Usb150Dump("final")
  [USB154] after-run: done, returning to BDS
  return EFI_SUCCESS                       ; 无 CpuDeadLoop
```

**关于 "清 RUN_STOP"**：DWC3 databook 中 `DCTL.RUN_STOP` bit31 = 1 表示 **run**、0 表示 stop。keys152 真机 pre 读数为 `DCTL=10F0000`（bit31=1? 实际该行打印的 DCTL=0x10F00000 → bit31=0）、`hlt22=1` ⇒ 控制器处于 **halted/stop** 状态。因此"清 RUN_STOP"不会让它运行；keys154 改为**确保 RUN_STOP=1**，并在写后读回校验。若真机上 `after-run` 的 `hlt22` 仍为 1、`lnk` 不变，则说明卡在 PHY/时钟/事件缓冲一侧（而非 DCTL）。

PHYCFG 位定义（keys154 使用）：`SUSPHY=bit6`、`ENBLSLPM=bit8`、`PHYSOFTRST=bit31`（清这三位的做法与 keys149/keys150 相同，仅在 keys154 中加了写前后读回校验）。

---

## 4. 离线验证（全部通过）

| 检查 | 结果 |
|---|---|
| FD 模块 diff vs keys152 | 90/90，0 增删，仅 Menu 变化 ✅ |
| SEC/PEI FFS sha | `cfcfca5e…`（= keys149/keys152）✅ |
| inner FVMAIN 长度 | 6,156,296 B（相同）✅ |
| img 内 FD == FD 文件 | True ✅ |
| img 尾部 DTB | 808,716 B，sha `71da250370a977dacc230bd7977ff43f397e388bf02a55c162b22662152c3891`（同 keys152）✅ |
| Menu UTF-16 标记 | `MENU154`×1、`USB154`×5、`USB150`×5 ✅ |
| Menu 反汇编扫 GCC | **无** `mov w8, #0xf004` / `movk w8, #0x10, lsl #16` ✅ |
| LogDisk / DtbExtn / UsbConfig 等 | 与 keys152 逐字节相同 ✅ |
| UFSDxe | 不在 FV ✅ |

---

## 5. 上机判据（keys154）

正常应看到（顺序）：

```text
[MENU102] entry: ConOut=1 ConIn=1
[MENU154] USB device-mode bring-up: pre-dump, PHYCFG/DCTL writes, no QSCRATCH
  [USB150] pre  id: GSNPSID=... GCTL=... GSTS=...
  [USB150] pre  cfg/dev/dec/phy
  [USB154] vbus readonly: HS=... SS=...
  [USB154] phycfg: before=... want=... after=... ok=1
  [USB154] dctl: before=... after=... run=1
  [USB154] after-run[0]: DSTS=... hlt22=? spd=? lnk=?
  [USB154] after-run[1]: DSTS=... hlt22=? spd=? lnk=?
  [USB150] final id/cfg/dev/dec/phy
  [USB154] after-run: done, returning to BDS
```

判读表：

| 现象 | 含义 |
|---|---|
| `ok=0`（PHYCFG 读回不一致） | 该寄存器只读或需 clock on；PHY 未上电 |
| `run=0`（DCTL 写回不一致） | DCTL bit31 被硬件/时钟门控锁住 |
| `after-run hlt22=0` 且 `lnk` 变化 | 控制器已 run，链路在协商（DSPS/PHY 侧问题） |
| `after-run hlt22=1` 持续 | 控制器仍 halted：查 GUSB2PHYCFG/GUSB3PIPECTL、PIPE 时钟、GCC（下次若需读 GCC，要先在 DXE 建映射） |
| 接着 BDS 能否枚举 | 关键看是否出现 `UsbConfigDxe` / `UsbInitDxe` 日志与 PC 侧是否出现设备 |

---

## 6. ⚠️ 重要：USB 寄存器写会污染后续 boot

keys152 真机的结果同时证明：

* 同样的字节 keys153 == keys149（逐字节相同）在**当天**却重启、进不了菜单，而昨天同字节可以进 → **上一版固件（keys150/keys152 的 USB 写）把硬件留在坏状态**，冷启动/断电后才恢复。
* 因此：**尽量不要在 firmware 里写 USB 寄存器**；必须写时要保证每次 boot 都从已知状态重建，且**写完后不要让该状态跨版本/跨重启残留**（必要时提示用户断电 10 s 再刷）。
* keys154 只写 `GUSB2PHYCFG`、`DCTL` 两个寄存器（每次 boot 从 POR 默认值重新开始），并保留只读打印用于诊断；**不写 QSCRATCH**。

---

## 7. keys152b（备用包，已出）

用途：若 keys154 仍在 Menu 内崩溃，用 keys152b 证明"是否是 DWC3 dump 本身引发"。
内容：Menu 只剩 `[MENU152B]` 两行打印（+ `RunMenu()` 引用分支），**无任何 DWC3/QSCRATCH 读、无写、无 CpuDeadLoop**。

| 文件 | SHA-256 | 大小 |
|---|---|---|
| `_k70port_extract/qemu-fw/SILICIUM_UEFI-keys152b.fd` | `1d00c4845986499de18ed99116d1982d05f790509f52f7010c0e620fb9d02f71` | 4,194,304 B |
| `K70-UEFI-build/Mu-vermeer-keys152b.img` | `75b00c433a299ec22f7d520fc91803c728343efb4221b3c1b61904818871967d` | 1,792,000 B |
| `K70-UEFI-build/K70-keys152b-NO-DUMP.img` | 同上（复制） | 1,792,000 B |

离线验证（vs keys152）：90 模块 / 0 增删，**仅 Menu 变化**（20,054 → 18,518 B，sha `fd27b1f3…` → `8a6546ef…`）；SEC/PEI sha `cfcfca5e…` 相同；inner FVMAIN 6,156,296 B 相同；img 内 FD 与 FD 文件一致；DTB 同 keys152（`71da2503…`）；Menu UTF-16 `MENU152B`×2、`USB150` 0；反汇编无 GCC 读取。

---

## 8. 改动清单

* `_tools/patch_usb154.py`（新增）：keys152 → keys154 的 Menu 变换（幂等锚 `Usb154Run`）。
* `_tools/patch_usb152b.py`（新增）：pristine keys149 Menu → keys152b（删 keys150 整块、stub SimpleFb、两行 Say）。
* `_tools/run154.sh` / `r154wrap.sh` / `run152b_spare.sh`（新增）：构建血缘与产物复制。
* `_tools/verify154.py`（新增）：FD 模块 diff / PEI sha / 容器 / DTB / Menu 标记 / GCC 反汇编扫描。
* 未改动：PEI/MemoryMapLib、UsbConfigDxe 二进制补丁（keys143/145/146 系列）、DtbExtn 的 `[VBUS]` 块、其它任何构建脚本。

---

## 9. 回退

* keys154 异常 → 刷 **keys152**（`0f0be4f2…`，最小 Menu、PEI 同 keys149），或 **keys153**（`d8784724…`，与 keys149 逐字节相同，纯回归基线）。
* keys154 若 UI 不显示/进不了菜单 → keys152b（待填 sha）。
