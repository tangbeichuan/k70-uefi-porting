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
---

## 完整性说明（这个仓库里到底有什么、没有什么）

### ✅ 已收录

| 类别 | 内容 | 位置 |
|---|---|---|
| 自研驱动 | 9 个 DXE 驱动**完整源码**（`.c` + `.inf`） | `drivers/` |
| 设计文档 | 9 篇（架构/驱动/USB/DTBExtn/UFS/踩坑/版本/日志） | `docs/01..09-*.md` |
| 真机完整记录 | 1100+ 行、从 keys0 到 keys168 的逐版本实测记录（含 sha256、屏上原文） | `docs/10-真机实验完整记录.md` |
| 逆向分析报告 | 24 份逐版本分析报告（寄存器解码、反汇编结论、修复方案） | `docs/reports/` |
| 构建脚本 | 295 个 WSL 构建/打包脚本（`build_keys*.sh`/`run_keys*.sh`/`pack_keys.sh`/`gates.py`…） | `scripts/wsl-full/` |
| 补丁脚本 | 940 个 `.py/.sh/.ps1` 工具与补丁（`patch_extn136.py`、`patch_usb126.py`…） | `scripts/tools-full/` |
| 里程碑镜像 | 60 个可直接 `fastboot boot` 的历史镜像 | `artifacts/` |

### ❌ 未收录（以及为什么）

| 内容 | 为什么没有 |
|---|---|
| **上游 Mu-Silicium / Project Silicium 源码树** | 那是别人的项目（`Platforms/Xiaomi/vermeerPkg` 基于 Kailua SM8550 支持）。本仓库只提供**我们的驱动与补丁**；构建时需自取上游，见下节 |
| **高通 vendor 二进制**（`Binaries/vermeer/QcomPkg/**/*.efi`） | 厂商专有二进制，不可再分发 |
| **从设备提取的镜像**（`xbl_a.img`、`boot_a.img`、`vendor_boot_a.img`、`recovery_a.img`） | 含设备专有数据/厂商内容，不适合公开 |
| **完整 `vermeer.fdf` / `vermeer.dsc` 成品** | 它们是上游文件 + 我们的补丁；补丁脚本已全部收录，可复现 |

### 🔧 复现构建（需要自备上游）

```bash
# 1. 取上游（Project Silicium，SM8550 Kailua 支持）
git clone https://github.com/Project-Silicium/Mu-Silicium.git
cd Mu-Silicium

# 2. 应用本仓库的驱动与补丁
cp -r <this-repo>/drivers/Vermeer*        Platforms/Xiaomi/vermeerPkg/Drivers/
cp    <this-repo>/drivers/VermeerDtDumpDxe/* Platforms/Xiaomi/vermeerPkg/Drivers/VermeerDtDumpDxe/

# 3. 注册（dsc Components / fdf / APRIORI.inc）
python3 <this-repo>/scripts/patches/patch_extn136.py Platforms/Xiaomi/vermeerPkg
python3 <this-repo>/scripts/patches/patch_menu101.py Platforms/Xiaomi/vermeerPkg

# 4. 编译（WSL / clang+LLD）
python3 build_uefi.py -d vermeer -m 0 -r DEBUG
```

### ⚠️ 关键工程规则（血泪，务必先读）

见 `docs/07-踩坑清单与工程规则.md`，其中三条最容易致命：

1. **不要往 FV 里新增独立模块**（会改布局把引导搞挂）——新功能内嵌进已有驱动；
2. `binaries` 的 INF 只能出现在 `Include/APRIORI.inc`，同时出现在 `Include/DXE.inc` 会 `GenFv ERROR 2000: same file GUID`；
3. `gBS->AddMemorySpace` **只登记 GCD、不建页表**；MMIO 必须写进 PEI 的 `MemoryMapLib.c` 才会真正映射。
