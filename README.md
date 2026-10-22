# K70 UEFI Porting（Redmi K70 / SM8550 / vermeer）

把 **Xiaomi Redmi K70（vermeer，Snapdragon 8 Gen 2 / SM8550）** 跑成一个可交互的 UEFI 环境：
静默引导进 DXE → 屏幕输出 → 音量键导航 → 图形菜单 → 设备信息 / 重启 / 关机，
并在此之上继续打通 **USB 设备模式调试口** 与 **UFS 存储**。

> 所有测试均为 `fastboot boot`（内存启动，不写分区）；失败可长按电源键重启，原系统不受影响。

## 现在能做什么（2026-10-22）

| 能力 | 状态 | 说明 |
|---|---|---|
| ABL 接受并跳入自编译固件 | ✅ | `fastboot boot` 直接进 DXE |
| SEC → PEI → DXE → BDS 全链路 | ✅ | 自研 MemoryMapLib 提供 42 条内存区（含 Display/UFS/SMMU） |
| 屏幕输出 | ✅ | `FrameBufferSerialPortLib`，1440×3200×32，30 ms/行 |
| 音量键 / 电源键输入 | ✅ | 音量上 `ScanCode 0x01`、音量下 `0x02`、电源键以 Enter(`0x0D`) 形式进入 `SimpleTextIn` |
| 图形菜单（GOP 自绘） | ✅ | 点阵字体 + 高亮条 + 子页面（`keys117`~`121`） |
| DTBExtn 协议 provider | ✅ | 自研 provider 让 `PmicDxe` 等厂商驱动能读到 `/soc/ufs0`、`/sw/pmic/...`（`keys136` 起） |
| USB 设备模式（DWC3） | 🟡 | 控制器已 RUN（`hlt22=0`）、D+ 已上拉、主机能看到 `VID_0000&PID_0002`；**EP0 描述符应答尚未通过** |
| UFS 块设备 | 🟡 | 寄存器可读、UIC 通路可用、`xbl_config` 里的 UEFI 设备树已定位；自研裸 UFS 卡在门铃写 |
| 文件系统 / 引导 OS | ❌ | 依赖 UFS |

## 快速开始

```bash
# 内存启动（推荐，不写分区）
fastboot boot K70-keys168-CONSOLE-MARKERS.img

# 或写入 boot 槽（会覆盖原厂 boot，务必先备份）
fastboot flash boot  <image>.img
fastboot reboot

# 还原原厂 boot
fastboot flash boot  boot_a.img
```

## 目录

```
docs/       设计与逆向文档（架构、驱动、USB、DTBExtn、UFS、踩坑、版本索引）
drivers/    自研 DXE 驱动源码（9 个）
scripts/    构建 / 打包 / 补丁脚本（从 294 个构建脚本中挑选关键路径）
artifacts/  里程碑镜像（keys14/44/70/121/150/168），可直接 fastboot boot
```

## 构建环境（概要）

- 上游：**Project Silicium / Mu-Silicium**（`vermeerPkg`，SM8550 支持基于 Qualcomm Kailua）
- WSL Ubuntu + 交叉工具链（clang/LLD）+ 仓库自带 `build_uefi.py`
- 构建：`python3 build_uefi.py -d vermeer -m 0 -r DEBUG`
- 打包：`BootShim` + FD + `vermeer.dtb` → `mkbootimg --header_version 1`
- 详细步骤见 `docs/02-系统架构与启动链路.md`

## 里程碑（挑重点）

| 版本 | 事件 |
|---|---|
| keys14 | 第一版能跑到菜单（vendor 栈 28 模块） |
| keys44 | 音量键真正变成 `SimpleTextIn` 事件 |
| keys70 | `UFSDxe` 首次加载；`MMU: 43 regions` 实验 |
| keys105 | 解决"两个 `SimpleTextIn`"导致按键失效 |
| keys117-121 | GOP 自绘图形菜单 + 电源键确认 |
| keys136 | DTBExtn provider 真正进 FV（`size=512` 修复） |
| keys150 | DWC3 device 模式 `PRTCAPDIR=2`、`hlt22=0` |
| keys168 | 无清屏 + 17 个路标行 + 常驻循环，用于定位 EP0 卡点 |

## 许可

MIT。上游组件（Project Silicium / Mu / Qualcomm binaries）各自遵循其许可。