# hackios-port —— K70(vermeer) 接入 HackiOS 的两个文件

这两个文件是为 `oosexgang/hackios-xnu-kernel` 准备的 **vermeer 机型描述**，不含 HackiOS 的代码，
也不含任何 Apple 文件。

| 文件 | 放到 HackiOS 树的哪里 |
|---|---|
| `vermeer.conf` | `common/devices/vermeer.conf` |
| `vermeer.platform.c` | 内容贴进 `xnuloader/loader.c`（`platform_redwood` 后面），并在 `platforms[]` 里加 `&platform_vermeer` |

## 用法

```sh
# 1) 取 HackiOS（两个仓库，kernel 会带出 userland）
git clone https://github.com/oosexgang/hackios-xnu-kernel.git hackios
cd hackios && common/setup.sh

# 2) 放进机型描述
cp <本目录>/vermeer.conf        common/devices/vermeer.conf
#   把 vermeer.platform.c 的内容贴进 xnuloader/loader.c，platforms[] 加一行：&platform_vermeer

# 3) 编 loader（aarch64 交叉）
xnuloader/build.sh

# 4) 用我们的 UEFI 镜像替换它的 prebuilt（我们自己的 4 MiB FD）
export UEFI_FD=/mnt/d/本地项目-01/K70-UEFI-build/SILICIUM_UEFI-<tag>.fd
export DTB=/mnt/d/本地项目-01/_k70port_extract/port/Resources/DTBs/vermeer.dtb
export FD_BASE=0xA7100000 FD_SIZE=0x400000 PAYLOAD_BASE=0x90000000

# 5) 打包并启动（注意：还需 BootManagerLib 的钩子，见下）
python3 mkxnuimg.py -p payload.bin -o xnu-vermeer.img
fastboot boot xnu-vermeer.img
```

## 我们这边还差的两件东西

1. **BootManagerLib 钩子**：HackiOS 的 `uefi/mu-silicium.patch` 把 BDS 换成“从 `PAYLOAD_BASE` 的 `XNUP`
   容器里 `StartImage(loader.efi)`”。我们的 `VermeerMenuDxe` 可以直接加一项 “Boot HackiOS”，
   在菜单里 `LoadImage` + `StartImage` 我们的 `loader.efi`，**不必改 BootShim、也不用 XNUP 容器**。
2. **USB 设备模式**：`xl enter/run/ramdisk/log/screenshot` 全部靠 loader 自己实现的 fastboot 协议，
   而它跑在 USB 上 —— 我们 UEFI 侧的 EP0（`keys168/169`）必须先把设备描述符答出来，否则主机只看到
   `VID_0000&PID_0002`（描述符请求失败）。

## 参数出处

全部字段的来源、以及 `io_base / gic / cores / small_cores / fb_base` 为什么取这些值，见
`docs/11-HackiOS移植对照.md`（第 3 节“从 vermeer DTB 直接读出的参数”）。
