# keys156 报告：USB bring-up 之后的存活检查（重启 vs 枚举 分离）

日期：2026-10-22
任务来源：lead m03476（keys154 真机 `hlt22=0`，重启发生在 USB bring-up 之后很久）
构建血缘：`build_keys154.sh` → `build_keys156.sh`（TAG=keys156）
基线：keys154（Menu 写 PHYCFG/DCTL，真机已验证 `DCTL 10F00000→30F00000`、`hlt22=0`、`spd=4`、`lnk=5`）

---

## 1. 改动（只有一处，Menu 内）

在 keys154 的 bring-up 块（`Usb154Run()`：PHYCFG 清 SUSPHY/ENBLSLPM/PHYSOFTRST → DCTL 置 RUN_STOP=1 → Stall 50ms×2 读 DSTS）之后、entry 返回之前，新增三行：

```c
Say (L"  [USB156] menu returned, waiting for BDS");
gBS->Stall (3000000);                 /* 3 s，期间中断仍被处理 */
Say (L"  [USB156] still alive after 3s");
```

- **不改** PHYCFG/DCTL 的写入顺序与参数（真机已验证的那套保持原样）；
- **不写** QSCRATCH、不读 GCC、不新增模块、不动 PEI/APRIOIR/FDF；
- 无 CpuDeadLoop（Menu 正常返回 EFI_SUCCESS，交回 BDS）。

补丁：`_tools/patch_usb156.py`（`keys154 → keys156`，幂等锚 `[USB156]`，要求基线同时存在 `Usb154Run` 与 `[MENU154]`）。
构建：`_tools/run156.sh`（`build_keys154.sh` sed 154→156 生成 `build_keys156.sh`，patch 链 `… patch_usb154.py && patch_usb156.py`，构建 + pack + 复制交付名）。
probe 结果：patch 链 sanity 全过（patch_usb156×1、nopmic×0、NO_HAL×0、UsbConfigDxe 备份/还原 trap×2），有效源码 entry 尾为 971 MENU154 / 982-984 USB156 三行，MemoryMapLib 无 GCC 行。

## 2. 产物

| 项 | 文件 | sha256 | size |
|---|---|---|---|
| img | `K70-UEFI-build/Mu-vermeer-keys156.img`（= `K70-keys156-ALIVE-CHECK.img`、`-fat.img`） | `9185fc59675e0c756c241251e643ee93a412312a64c55b22aa135cec39643ddb` | 1,794,048 |
| FD | `_k70port_extract/qemu-fw/SILICIUM_UEFI-keys156.fd` | `5121258d677cc37f42bb7b52c6b0b04452287d22ee2e1dbd2c8eecbff3a968bc` | 4,194,304 |
| 附 | `Mu-vermeer-keys156-v4.img` | `54fd4ebe18e801ef3642d3b7c528da305f7a02c1206ac3af1c66cd64770d41b9` | — |

回退：keys154 img `37cce641682af39f6abc2a7ddcd7d9aee49094cd1c9eadca5a47b42c36921155`、FD `1ed89cd3…`。

## 3. 离线验证（verify156.py）

- **模块 diff vs keys154：89/89、0 增删、只有 1 个模块变化 = VermeerMenuDxe（20,054 → 20,566 B）**。
- **SEC/PEI 与 keys154 逐字节相同**（size 65,440、sha `cfcfca5e…`、区域名 GCC×0 / USB×1）⇒ PEI 一字节未动。
- Menu（20,480 B）UTF-16：`MENU154`×1、`USB154`×5、`USB156`×2。
- Menu 反汇编：GCC 相关立即数 0 条（不会重演 keys152 崩在 0x0010F004）；`Stall(3000000)` 实际编入：
  ```
  1ec0 ldr  x8,[x24,#0xc38]      ; gBS (0xA?) + ... 实际是 gBS 指针
  1ec4 mov  w0,#0xc6c0
  1ec8 movk w0,#0x2d,lsl#16      ; w0 = 0x2DC6C0 = 3,000,000
  1ecc ldr  x8,[x8,#0xf8]        ; gBS->Stall
  1ed0 blr  x8
  1ed4 adrp x0,0x4000 ; add x0,#0xe10 ; Say("still alive after 3s")
  ```
- 容器：kernel 1,788,348、解压 4,194,496 = 0xC0(shim)+FD 4,194,304，img 内 FD == FD 文件；尾随 DTB 808,716 B sha `71da2503…` 与 keys154 相同。
- Guid.xref：UsbConfigDxe / UsbInitDxe / UsbMsdDxe / UsbfnDwc3Dxe / UsbDeviceDxe / PmicDxe / VermeerDtbExtnDxe / VermeerLogDiskDxe / VermeerMenuDxe / AcpiTableDxe / ClockDxe / HALIOMMU / PmicVerStubDxe 在；UFSDxe=0。

## 4. 现场判读（keys156）

排序预期（从上到下）：
```
[MENU154] USB device-mode bring-up: pre-dump, PHYCFG/DCTL writes, no QSCRATCH
[USB150] pre ...（5 行）
[USB154] vbus readonly: HS=… SS=…
[USB154] phycfg: before=… want=… after=… ok=1
[USB154] dctl : before=… after=… run=1
[USB154] after-run: DSTS=… hlt22=0 spd=… lnk=…
[USB156] menu returned, waiting for BDS      ← 新增
（约 3 秒后）
[USB156] still alive after 3s                ← 新增
（之后才是 BDS 加载各驱动的日志：`[DTBEXTN] …`、`Loading driver …` 等）
```

| 现象 | 结论 | 下一步 |
|---|---|---|
| 两行 `[USB156]` 都出现，之后才重启 | Menu/BDS 阶段正常，3 秒窗口内无复位 | 重启发生在更后面（BDS 无启动项 → ResetSystem，或 UsbMsd/UsbDevice/LogDisk 后续动作，或 USB 运行态在 BDS 阻塞期间触发中断风暴/看门狗）。下一步：BDS 阶段日志 / 关闭 USB 中断（DEVTEN=0）做对照 / 缩短到只 load 一个驱动 |
| 只有第一行，第二行没出现就重启 | **3 秒内被复位** ⇒ 强烈指向 USB device 运行态引起的中断风暴或看门狗 | 查 GIC/USB IRQ 与 DWC3 DEVTEN/GINTMSK；keys157 里在 bring-up 后写 `DEVTEN=0` + 屏蔽 GIC USB IRQ 做对照 |
| 连第一行都没出现 | 说明在 `[USB154] after-run` 到 Menu 返回之间就出事（不太可能，因为 keys154 已覆盖这段） | 抓最后一行 |

PC 侧枚举仍交给 `K70-USBDIAG.bat watch`；上一版（keys154）PC 侧没有任何 USB 设备出现，本版未改 USB 栈，预期仍不会枚举 —— 本版只解「重启发生在哪一段」。

## 5. 其它

- 源码树状态：`MemoryMapLib.c` 无 GCC 行（keys156 本就不加）；`VermeerMenuDxe.c` 为 keys156 内容（每次构建由 patch_menu101 从 port-drivers 重拷再打补丁，幂等）。
- 工具：`_tools/patch_usb156.py`、`_tools/run156.sh`、`_tools/verify156.py`；日志 `_tools/b156.log`、`b156_probe.log`、`v156.log`；`guid-keys156.xref`。
