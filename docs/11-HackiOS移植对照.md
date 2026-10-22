# HackiOS → K70 移植对照（2026-10-22）

参考对象：`oosexgang/hackios-xnu-kernel` + `oosexgang/hackios-xnu-userland`（另一个账号，公开仓库）。
本机已拉取文本源到 `D:\本地项目-01\_refs\hackios-xnu-kernel\`（185 个文本文件，2.68 MB；二进制只取了 `prebuilt/loader.efi`）。

> 说明：HackiOS 仓库内**不含任何 Apple 文件**；`ios165/fetch.sh` 从 Apple CDN 下载 iOS 16.5 IPSW 到本地再提取。

---

## 1. 它的启动链（和我们完全不同的一段）

```
fastboot boot xnu-<device>.img
        │
        ├── BootShim.bin        把 FD 复制到 FD_BASE，把 "XNUP" 容器复制到 PAYLOAD_BASE
        ├── SILICIUM_UEFI.fd    一个改过 BootManagerLib 的 Mu-Silicium UEFI
        └── XNUP 容器           gzip 里的第三段：loader.efi + kernel + 镜像（可选）
                │
                └── BootManagerLib 不再进菜单，而是从 PAYLOAD_BASE 直接 StartImage(loader.efi)
                        │
                        └── loader.efi 自己实现 **fastboot 协议**（getvar version ≥ 0.5）
                                ├── xl ramdisk system.apfs   上传系统镜像常驻内存
                                ├── xl run                   上传 kernel 并运行，回传日志
                                ├── xl log / screenshot      取日志与帧缓冲
                                └── xl reboot                回 Android
```

关键点：**他们不用菜单**。UEFI 直接把控制权交给 `loader.efi`，而 `loader.efi` 把手机伪装成一个
fastboot 设备，主机侧用 `./xl` 对话（上传内核/镜像、取日志/截图）。

## 2. 我们已有 / 还缺什么

| 环节 | HackiOS(redwood) | 我们(K70 vermeer) | 状态 |
|---|---|---|---|
| Mu-Silicium UEFI 平台包 | `uefi/files/Platforms/Xiaomi/redwoodPkg` | `Platforms/Xiaomi/vermeerPkg`（我们自建，已跑通） | ✅ |
| 显示 | DisplayDxe + GOP | `SimpleFbDxe` + 我们点阵绘制，1440×3200 @ `0xB8000000` | ✅ |
| 输入 | 触摸(GT9916)/按键 | 音量键（枚举 4 个 SimpleTextIn）+ 电源键 | ✅ |
| 菜单 | 无（直接进 loader） | `VermeerMenuDxe`（文本框 + GUI 两套） | ✅ |
| 日志盘 | 无（走 `xl log`） | `VermeerLogDiskDxe`（1 MiB FAT16 RAM 盘，可被 FAT 驱动识别） | ✅ |
| **USB 设备模式** | loader 自实现 fastboot | UEFI 侧 EP0 未通（主机看到 `VID_0000&PID_0002`，描述符无人应答） | ❌ **卡点** |
| `xnuloader` | `xnuloader/loader.c` 150 KB，含 `struct platform` | 无 | ❌ |
| XNU 内核 | `xnu/` 补丁 + `prebuilt/mach.development.bcm2837` | 无 | ❌ |
| 用户态/APFS | `hackios-xnu-userland`（init/inject/Mesa/APFS 构建） | 无 | ❌ |

**结论**：我们和 HackiOS 的差距集中在“loader + kernel + userland”，而进入这条链的**门票是 USB 设备模式**——
因为 `./xl` 全靠 loader 提供的 fastboot 协议跑在 USB 上。所以 `keys168/169` 的 EP0 工作不是支线，而是
HackiOS 路线的前置条件。

## 3. 从 vermeer DTB 直接读出的参数（`_twrp/Image/vendor_boot.dtb`）

| 字段（`struct platform`） | 值 | 来源 |
|---|---|---|
| `gic_dist` | `0x17100000`（size `0x10000`） | `arm,gic-v3` 的 `reg = <0x17100000 0x10000 0x17180000 0x200000>` |
| `gic_redist` | `0x17180000`（size `0x200000`） | 同上 |
| `cores` / `core_shift` | `8` / `8` | `cpu@0,100,200,300,400,500,600,700`（MPIDR 第二亲和域） |
| `small_cores` | `0x7`（cpu0/1/2） | `capacity-dmips-mhz = 0x334`（little），gold `0x708`，prime `0x766` |
| `io_base` / `io_size` | `0x00100000` / `0x3FF00000` | GCC `0x100000`、UFS `0x1D84000`、GIC `0x17100000`、TLMM `0x1F00000` 都在这一窗内；**不能从 0 起**（XNU 会跳过时钟初始化） |
| `uart` | `0` | 手机无 PL011 |
| `fb_base` | `0xB8000000` | 我们 `SimpleFbDxe` 上报的 GOP 帧缓冲（1440×3200） |
| `psci_hvc` | `0` | 手机走 SMC |

我们的 boot 链地址（供 `common/devices/vermeer.conf`）：

| 变量 | 值 | 说明 |
|---|---|---|
| `UEFI_TARGET` | `vermeer` | `build_uefi.py -d vermeer` |
| `FD_BASE` / `FD_SIZE` | `0x9FD00000` / `0x400000` | 我们 keys12 起用的 4 MiB FD（BootShim 已按此编译） |
| `PAYLOAD_BASE` | `0x8C000000` | 我们的内存图里 `0x80000000–0xB7FFFFFF` 是可用 DRAM，取 64 MiB 窗口 |
| `DTB` | `_twrp/Image/vendor_boot.dtb` | 8 棵拼接树，`dtc` 可解 |
| `BOOTARGS` | `touchscreen=0 cpus=8` | K70 触摸驱动未做，先只要按键 |

## 4. 建议路线（按依赖顺序）

| 步骤 | 内容 | 工作量 | 备注 |
|---|---|---|---|
| **S0** | 把 `keys168/169` 的 EP0 打通：主机能读到设备描述符（哪怕只是 `VID 0x1209/PID 0x0001`） | 中 | **所有后续步骤的前置**；也是 `xl` 的前提 |
| **S1** | 建 `common/devices/vermeer.conf` + `vermeer.platform.c`（用上表的值），把 `platform_vermeer` 加进 `loader.c` 的 `platforms[]` | 小 | 需要 `xnuloader/build.sh` 的 aarch64 工具链 |
| **S2** | 编 `loader.efi`（vermeer 版），先用**我们的 Stage2 机制**把它当普通 EFI 应用内嵌进 FV，菜单加一项 “Boot HackiOS” | 中 | 不需要动 BootShim/XNUP；先验证 loader 能在 K70 上起来、能认平台、能画屏 |
| **S3** | 让 loader 的 fastboot 协议在 K70 的 USB 上工作（`xl enter/state/log`） | 大 | 与 S0 同源；loader 内部可能有自己的 DWC3 驱动，需要对齐我们的寄存器窗口 |
| **S4** | 内核：把 `xnu/` 的补丁移植到 vermeer（GIC/timer/PMIC/显示/按键先跑通，触摸/GPU/Wi-Fi 后做） | 很大 | 他们 redwood 的机型代码在 `bsd/dev/redwood_*.c`，SM8550 需要新写 |
| **S5** | 用户态：`hackios-xnu-userland` 的 `userland/build.sh` 造 `root.apfs`/`system.apfs`（需本地取 iOS 16.5 IPSW） | 大 | 与内核并行，但依赖 S4 的 syscall 面 |

短期最现实的里程碑（与 PORTING.md 一致）：**S2 完成 = loader 自己的屏幕 + 日志**；再往后才是内核文本 `-v`。

## 5. 可以立刻做的三件事

1. **固化本次调研**：`_refs/hackios-xnu-kernel/` 已含 185 个文本源（含 `docs/PORTING.md`、`docs/checks.md`、
   `uefi/mu-silicium.patch`、`BootManagerLib/XnuLoader.[ch]`、`xnuloader/loader.c`、`common/*.sh`、`xl`），
   以及 `prebuilt/loader.efi`（66.5 KB，sha256 `9749fa6c…`）——可直接反汇编看它怎么实现 fastboot。
2. **对照我们自己的 UEFI 改动**：`docs/02-关键技术发现.md` 里逐条与 `uefi/mu-silicium.patch` 比对，
   看有没有我们已经踩过、他们换了个解法的点（例如他们直接换掉 BootManagerLib，而不是修 EnvDxe/DTBExtn）。
3. **补 `docs/08-版本索引.md`**：现在只写到 keys121，需要按 60 个 `v/keysNNN` 分支重新生成。

## 6. 许可与合规

- HackiOS 两个仓库都是公开源码（仓库内含 `LICENSE`，`prebuilt/NOTICES.md` 11 KB 列了三方组件）；
- 我们只**参考**其 UEFI/loader 的结构与接口，不复制 Apple 的任何文件；iOS 用户态在本机从 IPSW 获取；
- 我们自己的 `k70-uefi-porting` 保持 MIT，移植产生的 vermeer 代码独立实现。
