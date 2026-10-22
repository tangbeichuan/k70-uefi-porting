#!/bin/bash
# append145_report.sh -- append the keys145 section to KEYS143_REPORT.md
set -e
R=/mnt/d/本地项目-01/_tools/KEYS143_REPORT.md
cat >> "$R" <<'EOF'

## keys145（HALIOMMU 恢复 + UsbConfigDxe 0x53CC NULL 守卫）

### 为什么做这两件事
keys144 真机崩溃日志（lead 提供）：
```
ESR : EC 0x25 IL 0x1 ISS 0x00000007   (data abort, translation fault level 3, read)
ELR = 0x0000C5B4E0FF0   FAR = 0x0000000000000008
X0  = 0x8000000000000E (EFI_NOT_FOUND)   X8 = 0   X20 = 0xC64F0000   X25 = 0xC7115000
ASSERT [ArmCpuDxe] CpuExceptionHandlerLib.c(438)
```
- `FAR=8` + `X8=0` 指向“以 NULL 为基址读 +8”。全镜像按页对齐基址反推（ELR 低 12 位应为故障指令 RVA 的低 12 位）后，没有任何模块在 RVA 0xFF0 有代码 ⇒ **ELR=0xC5B4E0FF0 很可能是照片 OCR 误读**，不能作为唯一定位依据。
- 在 UsbConfigDxe 内找到唯一完全吻合的站点：`0x53CC ldr x8,[x8,#0x8]`，其中 `0x53C8 ldr x8,[x8,#0x770]` = 全局 gIommuCtx（0x13770）。keys144 没有 HAL IOMMU 生产者 ⇒ gIommuCtx == NULL ⇒ 正是 `[0x0+8]`。
- 该拆卸路径 `0x5364/0x5394/0x53C4` 只有“初始化标志 0x13780 为 0 才跳过”的保护，缺 IOMMU 时标志被置 1 而 ctx 为 NULL（0x3FA8 加固只挡住初始化分支，挡不住拆卸分支）⇒ 需要真正的生产者 + 兜底 NULL 守卫。
- 已排除 UsbMassStorageDxe 0x2FF0（其 x8 = X25+X22，且 0x2FD8 预索引读已成功过）。
- `X4=0x9A` 与本故障无关，是上一次调用遗留的标量；`X0=EFI_NOT_FOUND` 也是遗留返回值（崩溃发生在 `ldr`，不是函数返回）。

### 改动（相对 keys144）
1. **恢复厂商 HAL IOMMU 生产者**（与 keys143 相同机制，未加 NO_HAL）：
   - `Include/DXE.inc:54` ← `# [keys70-hard] INF …/HALIOMMUDxe/HALIOMMUDxe.inf` 解注释；
   - `Include/APRIORI.inc:37` 解注释，且 provider（`VermeerDtbExtnDxe`，第 4 行）在其之前；
   - HALIOMMUDxe depex = 12 个 arch 协议全 AND，进 FV 即可 dispatch，无需改 depex；
   - DT 需求 `/soc/iort` 全部字段本树都有（keys142 已核对），无需改 DTS。
2. **UsbConfigDxe.patched.efi 拆卸路径 NULL 守卫**（文件偏移=RVA，4 个 u32，先验字节、幂等）：
```
0x53CC  F9400508 -> B4000128   ldr x8,[x8,#8]  -> cbz x8,0x53f0
0x53D0  D0000069 -> F9400508   adrp x9,0x13000 -> ldr x8,[x8,#8]
0x53D4  F90003E9 -> D0000069   str x9,[sp]     -> adrp x9,0x13000
0x53E0  F94003E9 -> D0000069   ldr x9,[sp]     -> adrp x9,0x13000
```
   反汇编结果：
```
53c4 adrp x8,0x13000 ; 53c8 ldr x8,[x8,#0x770] ; 53cc cbz x8,0x53f0
53d0 ldr x8,[x8,#8] ; 53d4 adrp x9,0x13000 ; 53d8 ldr x0,[x9,#0x778] ; 53dc blr x8
53e0 adrp x9,0x13000 ; 53e4 mov x8,xzr ; 53e8 str x8,[x9,#0x778] ; 53ec b 0x53f0
```
   即使 IOMMU 仍缺失，拆卸路径也只会跳过，不会 `[0x8]` 崩溃。
3. 保留 keys144 全部内容（ClockDxe 在 UsbConfigDxe 之前、keys143b 的 0x3FA8 `tbz w8,#0x1f` 加固、keys140 provider、AcpiTableDxe、UsbConfigDxe/UsbInitDxe/UsbMsdDxe 放置）。

### probe 实证（`_tools/b145_probe.log`）
- DXE.inc:54 HALIOMMU active；APRIORI `:4 provider / :37 HALIOMMU / :172 stub / :173 ClockDxe / :174 UsbConfigDxe / :175 UsbInitDxe / :176 UsbMsdDxe`；
- 构建期 UsbConfigDxe 0x3FA8=`0802f836`、0x53CC=`280100b4 080540f9 690000d0`；构建结束 restore trap 还原回 `0802f8b6` / `080540f9 690000d0 e90300f9`；
- patch_fat137 全部检查 OK。

### 产物与验证（verify145.sh / verify145b.sh / verify145c.sh）
- FD `_k70port_extract/qemu-fw/SILICIUM_UEFI-keys145.fd`：4,194,304 B，sha256=`b36597931d1871d9cf5454b470a222c80c3fa14d9e8cee8da2f954521f1aa247`
- 镜像 `K70-UEFI-build/Mu-vermeer-keys145.img`：1,796,096 B，sha256=`7660a804a85d82211cf096fe0f8056c9c1ba6ea835a1823bc4e1688dc9a24f6b`
- 交付副本 `K70-UEFI-build/K70-keys145-IOMMU-GUARD.img`：同 sha256
- Guid.xref：新增 `9A00771F-36D4-4DD5-8916-C48ED9B16B86 HALIOMMU`；ClockDxe、UsbConfigDxe、UsbInitDxe、UsbMsdDxe、UsbfnDwc3Dxe、UsbDeviceDxe、PmicDxe、VermeerDtbExtnDxe、VermeerLogDiskDxe、VermeerMenuDxe、AcpiTableDxe、VermeerPmicVerStubDxe 全在；UFSDxe 0。
- FVMAIN.inf 放置行：25 UsbfnDwc3Dxe、53 HALIOMMU、57 PmicDxe、69 ClockDxe、89 UsbMsdDxe、90 UsbConfigDxe、91 UsbInitDxe、96 VermeerDtbExtnDxe、101 AcpiTableDxe。
- FVMAIN.Fv：6,160,384 B；HALIOMMU GUID ×3、ClockDxe GUID ×3；UsbConfigDxe FFS 86,170 B（payload MZ@+0x64），`0x3FA8=0802f836`、`0x53CC=280100b4`、`0x53D0=080540f9`、`0x53D4=690000d0`、`0x53E0=690000d0`，且 pristine 的 `080540f9 690000d0 e90300f9` 在 payload 中不存在 ⇒ 补丁确实进 FV。
- DTB：FV 内 1 份，与 `xbl_ufs.dtb` 逐字节相同（57,217 B，sha256 `78c55f2e08136cbfa4f8c2fdfaae66ce67306f7a65395536c4568e92213a3f56`）。
- 构建结束 `UsbConfigDxe.patched.efi` 已还原为 pristine（0x3FA8=`0802f8b6`、0x53CC=`080540f9`）。

### 上机预期 / 下次真机看哪几行
1. 不应再出现 `ASSERT [ArmCpuDxe] CpuExceptionHandlerLib.c(438)` 的 `FAR=0x8` 崩溃；
2. HALIOMMU dispatch 后应出现 IOMMU 初始化相关日志，**不应**再打印 `Failed to open HAL IOMMU protocol Status = (0x%x)`（UsbConfigDxe 0x3FB0，str@0x10109）；
3. ClockDxe 在 UsbConfigDxe 之前（APRIORI 173<174、FVMAIN.inf 69<90），**`DisableUsbClocks: ClockProtocol unavailable` 应当消失**；若仍出现，说明 ClockDxe 没真正 InstallProtocol 或自身 dispatch 失败，需单独查 ClockDxe；
4. USB 继续往下走时，下一步重点看 UsbfnDwc3Dxe/UsbDeviceDxe 读取 `/soc/usb0/hs_phy_cfg`、`/soc/usb0/ss_phy_cfg` 的 `table` 属性日志（`HS: usb_shared_xbl_dtb_node_init …`、`usb_shared_process_phy_reg_dtb_list Failed`），hs 表在 DT 里是 `0xffffffff 0x00` 哨兵对，若 PHY 初始化被跳过属 vendor 语义，可能是下一个待解点；
5. 若出现新的 data abort，请同时给 ESR/ELR/FAR/X0..X8 与当时屏上最后 10 行日志；ELR 建议直接拍照或抄全 16 进制（本次 ELR 低 12 位为 0xFF0，与任何模块的代码段起始 0x1000 矛盾，疑似 OCR 误读）。

### 未改动项
vermeer.dsc、vermeer.fdf（仅 AcpiTableDxe 那一行由 keys142 解注释）、所有 _k70port_extract 下的构建脚本、provider 源码（VermeerDtbExtnDxe.c）、PmicDxeLa 及其它 QcomPkg 二进制、UsbConfigDxe 除上述 4 个 u32 外的字节。keys143b 的镜像/FD 未覆盖。
EOF
echo "appended, report lines=$(wc -l < "$R")"
