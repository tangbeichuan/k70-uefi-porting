# 04 · USB 设备模式调试口（进行中）

目标：把手机变成**能被 PC 认到的 USB 设备**，最终出 CDC-ACM 串口，让 UEFI 日志直接流到电脑，彻底摆脱拍照。

## 已经确认的事实（全部来自真机日志）

| 项 | 值 | 来源 |
|---|---|---|
| 控制器 | DWC3 @ `0x0A600000` | `GSNPSID=55331310`（真机读回） |
| QSCRATCH | `0x0A6F8800` | `GEN/HS/SS` 寄存器命中 |
| VBUS 覆盖 | `HS` 置 `bit20(UTMI_OTG_VBUS_VALID)`+`bit28(SW_SESSVLD_SEL)`；`SS` 置 `bit24(LANE0_PWR_PRESENT)` | `[VBUS] after HS=10100000 SS=01000000` |
| device 模式 | `GCTL.PRTCAPDIR=2` | `[VBUS]` 后续 + 主机能看到设备 |
| 控制器启动 | `DCTL.RUN_STOP=1`、`DSTS.bit22(hlt22)=0` | `[UFS71]/[150] … hlt22=0` |
| 事件环 | 4 KiB，`GEVNTSIZ=0x80001000`（masked）、`DEVTEN=0x1277` | vendor 对齐写序 |
| DWC3 SID | **0x40**（不是 UFS 的 0x60） | `xbl_ufs.dtb` 的 `/soc/iort/NAMEDNODE_USB0` → `OutputBase=0x40` |
| SMMU | `0x15000000`、SMMU-500；`S2CR.TYPE: 0=translate / 1=bypass / 2=fault` | 自研旁路写 `1<<16` |

## 现在卡在哪

```
手机：VBUS ✅  RUN ✅  D+ 上拉 ✅        →  PC 能看到设备
PC  ：设备出现在设备管理器，但报 "设备描述符请求失败"
     → USB\VID_0000&PID_0002   （说明主机发了 SETUP，我们没应答）
手机：GEVNTCOUNT 长期为 0（keys162~165 读数）
```

两种可能，`keys168` 的路标就是为区分它们：

1. **事件 DMA 没写回**（SMMU 旁路没生效 / 事件环地址或 DEVTEN 不对）→ `evts=0`；
2. **事件有写回，但 EP0 配置/应答写错**（TRB、DEPCMD、方向）→ 有 `evt raw` 但无 `setup` 或 `setup` 后主机仍失败。

## 实验台阶（每一版一个变量）

| 版本 | 变更 | 结果 |
|---|---|---|
| keys150 | `GCTL.PRTCAPDIR=2` + RUN + Stall | `hlt22=0`，PC 首次出现设备 |
| keys155 | 只读 GCC，不写 DWC3 | 证明早期 hlt22=1 是正常 |
| keys158 | 早期 bring-up + 清 `DEVTEN` | PC 看到 `VID_0000&PID_0002` |
| keys160 | 加 `DCTL.CSFTRST` 软复位 | ❌ 复位把 `GUSB2PHYCFG` 打回 SUSPHY，设备彻底消失 |
| keys161 | 去掉软复位 | PC 再次看到设备 |
| keys162-166 | 事件追踪（EP0-ARM、raw event、SMMU 旁路、replug） | 事件环仍然 0；但这几版**不再崩溃** |
| keys167 | 最小 EP0 应答（VID 0x1209 / PID 0x0001） | 主机仍报描述符失败（EP0 未真正应答） |
| keys168 | 去清屏 + 17 个 `[168]` 路标 + 常驻循环 + 每 5 s replug | 用于"最后一行定卡点" |

## 关键教训

1. **不要写 `DCTL.CSFTRST`**：它会重置 `GUSB2PHYCFG`（SUSPHY/ENBLSLPM 复原），设备直接从主机上消失。
2. **不要在 GOP 上整屏清屏**：控制台输出会被盖住，看起来像"黑屏崩溃"。
3. **`DWC3` 与 `UFS` 的 SMMU SID 不同**（0x40 vs 0x60），不能复用。
4. **vendor 的 `UsbConfigDxe` 有 IOMMU 依赖**：强制走 no-IOMMU 回退能让固件不崩，但 USB 侧 SMMU 映射也就没了；如果最终确认事件 DMA 被 SMMU 拦，就必须回头处理这块。

## 后续路线

1. `keys168` 读数 → 定"无事件"还是"EP0 写错"；
2. 若事件通：把 config descriptor 换成 **CDC-ACM（2 接口 3 端点）**，Windows 出 COM 口；
3. 若事件不通：试 `DEVTEN=0x7`、事件环换到 `0x0A600000` 邻域、或检查 `GEVNTSIZ.bit31`；
4. 通了之后：把 `BOOTLOG.TXT` / 实时日志写进内置 FAT 盘（或直接 COM 流），交付给 PC。