# 06 · UFS 进展与未解问题

## 目标

让 UEFI 拥有 UFS 块设备 → 上面放 FAT/ESP → 菜单第一项能真正启动 Linux / UniXNU。

## 两条路

### A. 用原厂 `UFSDxe`（目前在走）

已经做到：

```
[UFSMAP] AddMemorySpace 0x1d80000+0x20000 -> Success      （keys84 起）
Loading driver … UFSDxe.efi
UFS IOMMU LocateProtocol failed 0xE                        （HALIOMMU 被强制回退）
UFS SMMU Config failed
Error: Image at … start failed: Device Error
```

`keys145` 恢复 `HALIOMMU` 之后，`UsbConfig` 那边我们用"强制 no-IOMMU 回退"绕过了崩溃，
但 UFS 侧的 IOMMU 依赖仍未真正满足 —— 这是下一步要解决的（要么补 SMMU 映射，要么把 `HALIOMMU` 的 IORT 需求喂饱）。

### B. 自研裸 UFS（已跑通一部分，卡在门铃）

参考 `ios-vermeer-lab`（同作者、同 K70）的裸机做法，我们实现了：

```
[UFS71] dma=0x0BDFF4000 size=0x8000
[UFS71] smmu guard (0=ok)=1  id2=0x5111
[UFS71] host idle ok                     ← 寄存器可读
[UFS75] DME_GET(0x00) res=0 / (0x02) res=5 / (0x04) res=5 / LINK_STARTUP res=0   ← UIC 通
[UFS79] HCE=0/1 … UCRDY not ready        ← 主机复位实验（已废弃）
```

**卡点**：`wr(0x58, 1)`（UTRLC doorbell）之后整机停住，连下一行都打不出来。

已知排查结论：

- 不是电源/时钟（`GCC` 寄存器 `gdscr=F822F000`，bit31 电源域已开）；
- 不是 SMMU 翻译（`CR0.bit0=0`，SMMUEN 关）；
- 不是 PHY 映射（`UFS` 窗口已映射、`host idle ok` 通过）；
- 剩下高度可疑：**UTRD 字段编码**（与 Linux `ufshcd` 对齐）、**DMA 可见性**、**门铃写触发 axi 错误**。

关键参考（`scripts/ufs/` 里有摘录）：

- 寄存器：`0x50 UTRLBA / 0x54 UTRLBA_HI / 0x58 UTRLDBR / 0x60 UTRLRSR / 0x70 UTMRLBA / 0x90 UICCMD`
- 传输：32 KiB DMA（`0x8000`），命令 UPIU 在 `+0x1000`，数据在 `+0x4000`，响应在 `COMMAND+512`，PRDT 在 `Cmd+1024`
- UTRD：`utrd[0]=(1<<28)|(dir<<25)|(1<<24)`、`utrd[2]=15`、`utrd[4/5]`=命令地址、`utrd[6]=(128<<16)|128`、有数据时 `utrd[7]=(256<<16)|1`
- 完成判定：**`OCS != 15` 才算完成**（门铃清零不能证明命令被接受）

## 关键静态事实

| 项 | 值 |
|---|---|
| UFS 设备 | SAMSUNG KLUEG4RHHD-B0G1，fw 1801 |
| 逻辑块 | 4096（全部 6 个 LUN） |
| LUN 布局（TWRP 实测） | `sda` LUN0 / `sdb,sdc` 10 MB / `sdd` 16 MB / `sde` 1.2 GB（`boot_a=sde14`、`dtbo_a=sde18`、`abl_a=sde11`）/ `sdf` 32 MB |
| 控制器节点 | `/dev/block/platform/soc/1d84000.ufshc` |
| 实测 CAP | `0x3587031F`（与 `show_hba` 一致） |
| 参数来源 | `xbl_config_fdt_cb20.dtb` 的 `/soc/ufs0@1D80000`：`reg=<0x1d80000 0x7000>`、`FUA_Value`、`LinkStartupRetryCount=<5>`、`timeout_values{fDeviceInitTimeoutUs=<0x2625a0>;UTRDPollTimeoutUs=<0x1c9c380>}`、`init_speed_params`/`perf_speed_params` |

## 下一步

1. 用 `keys168` 的同一套思路给 UFS 也做"路标版"：只读 + 分步打印，先确认 `wr(0x58,1)` 到底是不是 axi 挂死；
2. 若是 UTRD 编码错 → 按 Linux `ufshcd` 逐字段重写；
3. 若是 DMA 不可见 → 处理 SMMU（复用 USB 那边学到的 S2CR 旁路经验）；
4. 打通后接 FAT 驱动 → ESP → 菜单第一项。