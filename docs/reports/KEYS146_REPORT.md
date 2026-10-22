# keys146 报告 —— UsbConfigDxe IOMMU 路径强制回退（"transact" 崩溃修复）

日期：2026-10-22 02:2x ｜ 基线：keys145（ClockDxe + HALIOMMU + 0x53CC 拆卸守卫）
构建血缘：`_tools/run146.sh` → `_k70port_extract/wsl/build_keys146.sh` / `run_keys146.sh`

---

## 1. 产物（可直接刷）

| 产物 | 大小 | sha256 |
|---|---|---|
| `_k70port_extract/qemu-fw/SILICIUM_UEFI-keys146.fd` | 4,194,304 B | `7c6e48a30fd0d40e65a0e23f9c0ec7c31c008df99ed0078f00d8c9d0cf3f272f` |
| `K70-UEFI-build/Mu-vermeer-keys146.img` | 1,796,096 B | `fefa1c2e24942bbc7e9bc77bf2d462b92aa1e1a300b1bb03c80420bffdd99661` |
| `K70-UEFI-build/K70-keys146-NO-IOMMU-INIT.img`（副本，同 sha） | 1,796,096 B | `fefa1c2e24942bbc7e9bc77bf2d462b92aa1e1a300b1bb03c80420bffdd99661` |

keys143b / keys145 的 FD 与 img 均未覆盖（仍在原处）。

**与 keys145 的唯一差别**：`UsbConfigDxe.patched.efi` RVA `0x3FA8` 一条指令

```
36 F8 02 08  tbz  w8,#0x1f,0x3fe8     (keys143/145 的“加固”，实测无效)
   ↓  改为
14 00 00 02  b    0x3fb0              (keys146：无条件走厂商自己的 no-IOMMU 回退分支)
```

其余全部沿用 keys145：ClockDxe 在 FV、HALIOMMU 在 FV、0x53CC 反初始化 NULL 守卫、AcpiTableDxe、provider 槽位、DTB 同源。

---

## 2. 崩溃真相：0x3FA8 之前的补丁从来就没修对

`UsbConfigDxe.patched.efi`（RVA = 文件偏移，keys145/146 FV 内 payload 与 Binaries 副本一致，86,016 B）：

```
3f68  adrp x8,0x13000 ; 3f6c ldr x8,[x8,#0x768]   ; gIommu
3f70  cbnz x8,0x41c8                              ; 已有接口就跳过
3f78  ldr x8,[x8,#0x6e8]                          ; gBS
3f80  ldr x8,[x8,#0x140]                          ; gBS->LocateProtocol
3f84  adrp x0,0x13000 ; 3f88 add x0,#0x1b8        ; GUID 54B6D3B4-… (HAL IOMMU)
3f8c  adrp x2,0x13000 ; 3f90 add x2,#0x768        ; &gIommu
3f94  mov x1,xzr ; 3f98 blr x8
3f9c  mov w8,w0                                   ; ★ 64 位 EFI_STATUS 被截成 32 位
3fa0  stur w8,[x29,#-0x24] ; 3fa4 ldur w8,[x29,#-0x24]
3fa8  tbz x8,#0x3f,0x3fe8                         ; 原始 bug：w8 零扩展 => bit63 恒 0
3fb0  [错误回退] str xzr,[0x13768] ; 打印 "Failed to open HAL IOMMU protocol Status = (0x%x)" ; b 0x41c4
3fe8  ldr x8,[0x13768]                            ; 成功路径唯一入口
3ff0  ldr x8,[x8,#0x8]                            ; keys144 崩溃点（gIommu==NULL → FAR=8）
3ff4  x0=&0x13770(gIommuCtx) ; 3ffc str x0,[sp,#0x18]
4000  blr x8                                      ; keys145 崩溃点（x8 = ASCII "transact"）
```

关键算术：`EFI_NOT_FOUND = 0x800000000000000E`，`mov w8,w0` 后 **w8 = 0x0000000E**。

- 原始 `tbz x8,#0x3f`：测 bit63，零扩展后恒 0 ⇒ 永远当“成功”，即使 Locate 失败；
- keys143/144/145 的 `tbz w8,#0x1f`：测 bit31，`0x0E` 的 bit31 也是 0 ⇒ **同样永远当“成功”**。

所以：
- keys144（HALIOMMU 不在 FV）→ Locate 返回 `0x8000000000000E` → 仍跳 0x3FE8 → `gIommu` 为 NULL → 0x3FF0 `FAR=0x8` 崩溃。与 lead 给的 ELR RVA `0x3FF0`、`X0=0x8000000000000E`、`X8=0` 完全吻合。
- keys145（HALIOMMU 已在 FV）→ Locate 成功 → `gIommu` 拿到某指针，但 `[gIommu+8]` 读出 8 字节 ASCII `"transact"` → 0x4000 `blr` 跳到 `0x746361736E617274` 崩溃。与 lead 给的 `PC/ELR=0x746361736E617274`、栈帧 `…C6472004 (0xC646E000+0x4004)` 吻合。

**keys146 正确做法**：不再试图“判定 EFI_ERROR”（vendor 的判定本身已被截断破坏），而是无条件跳到厂商写好且安全的回退分支 `0x3FB0`。该分支会：
1. 把 `gIommu(0x13768)` 清 0；
2. DebugPrint 一行 `Failed to open HAL IOMMU protocol Status = (0x0)`（Status=0 是因为 Locate 其实成功，这行变成我们的“强制回退标记”）；
3. `b 0x41C4` 正常返回，`0x13780/0x13781` 两个标志保持 0。

由全量引用扫描（`_tools/usb146_refs2.py`）确认：`0x13770/0x13778` 只在初始化块（0x3F68-0x41C8）与拆卸块（0x5364-0x53E8）里用，且后者入口先判 `0x13780`。⇒ 强制回退后，后续所有 IOMMU 映射/拆卸调用全部被跳过，不会再有 `[gIommu+8]` 这类解引用。

---

## 3. lead 四问逐条回答

### ① 0x3F00~0x4100 与 0x88C0~0x8960 反汇编
- `0x3F00~0x4100`：见上节。崩溃指令确为 `0x4000 blr x8`（源=RVA 0x3FF0 的 `ldr x8,[x8,#0x8]`）；`0x4004` 只是 **blr 的返回地址**，不是崩溃指令，所以栈里出现 `…C6472004 +0x4004` 是正常的调用链记录。
- `0x88C0~0x8960`（栈里 `0x8910` 的位置）：
```
88dc adrp x8,0x13000 ; ldr x8,[x8,#0x800] ; cbnz 0x8950   ; [0x13800] 已初始化 -> 跳过
88ec ldur x8,[x29,#-8] ; cbnz 0x8950
88f8 bl 0x9b10                                            ; UsbConfigLibOpenProtocols
8904 ldr x8,[sp,#8]
8908 b6f801a8 tbz x8,#0x3f,0x893c                         ; 这里才是正确写法：x8 未被截断
8910 b 0x8914                                             ; ← 栈里出现的 0x8910 只是错误日志标签
8914 ldr x3,[sp,#8] ; x1="%a: UsbConfigLibOpenProtocols failed %r" ; x2="UsbConfigCoresInit"
893c b 0x8940 ; 8940 mov w8,#1 ; str x8,[0x13800]         ; 成功置初始化标志
```
  结论：**0x8910 只是错误日志分支的标签，不是调用点**，栈回溯把它当返回地址属解析噪声；这条链本身没有把 data 当函数指针。

### ② 三个地址
- `X0=0xC6481770` = `UsbConfigDxe base(0xC646E000) + 0x13770` = **`&gIommuCtx`**。它正是 `0x3FF8 add x0,x0,#0x770` 写进 `[sp,#0x18]` 的出参地址 ⇒ 证明崩溃帧就是 0x3F68 这个 IOMMU 初始化函数。
- `X20=0xC6481000` = `base + 0x13000` = **UsbConfigDxe `.data` 页首**。该页内：gBS@+0x6e8、gIommu@+0x768、gIommuCtx@+0x770、gIommuBuf@+0x778、标志@+0x780/+0x781、SDT 协议@+0x7c8、Clock 协议@+0x7d8、CoresInit 标志@+0x800；这些在文件里全是 0（BSS）。
- `X1=0xC69453D0` = `base + 0x4D73D0`，**在 UsbConfigDxe 映像（约 0x14000）之外**，不可能是本模块的 .text/.data，也不是我们 provider/LogDisk 的静态地址。它只是崩溃瞬间 X1 的残留值（大概率是另一个模块的堆/DT 指针），与本次调用无因果关系，静态无法进一步归属。
- 我们 provider 不分配该地址段：provider 只返回 DTB blob 内的节点偏移句柄；LogDisk 只有自己的 1 MiB FAT 缓冲与 BlockIO 结构。

### ③ `grep "transact"`
- `xbl_ufs.dtb`：**0 处**。
- 我们自研驱动（VermeerDtbExtnDxe / VermeerLogDiskDxe / sticker）：**0 处**。
- `FVMAIN.Fv`：命中都**不是字符串开头**，而是更长调试串的内部：
  - `UsbfnDwc3Dxe +0x12f7c` `"total transaction length[%d] not a multiple of"`；
  - `PmicDxe +0x2dc2c` `"…SPMI transaction…"`；
  - `NpaDxe` 多处 `npa_begin_transaction` / `npa_fork_transaction` 等；
  - `SPMI +0x68e5` `"…SPMI transaction…"`。
- 结论：`0x746361736E617274` **不是任何字符串的起始地址**，而是把内存中 `"transact"` 这 8 个字节**当指针值**读了出来 ⇒ `gIommu`（或协议数据库里 GUID 54B6D3B4 的 Interface 指针）在运行期指向了一块“含 ASCII 的结构”，典型特征是结构体/接口布局错位或运行期数据被写坏，而不是单纯“少放一个驱动”。

### ④ ClockDxe 是否真装上了时钟协议
- 是。keys145 屏上**没有**出现 `DisableUsbClocks: ClockProtocol unavailable`。
- 代码侧：`0x9b48~0x9b74` 惰性 `LocateProtocol(gEfiClockProtocolGuid 241AFAE6…)`，失败才在 `0x7ed8` 打印 `%a: ClockProtocol unavailable` 并把 status 置 `0x800000000000000E` 返回。
- 构建侧：APRIORI `173 ClockDxe < 174 UsbConfigDxe`，FVMAIN.inf `69 ClockDxe < 90 UsbConfigDxe`，FVMAIN.Fv 内 `241AFAE6` 由 0 次变 10 次（`ClockDxe` 自身 GUID 也已入 FVMAIN.inf 第 69 项）。⇒ 时钟协议已就绪，后续问题不在时钟。

---

## 4. HALIOMMU 接口为什么会被读成 ASCII（诚实结论）

已核实（`_tools/usb146_halcmp2.py`）：
- keys145 FV 里的 HALIOMMU PE payload 与 `Binaries/vermeer/QcomPkg/Drivers/HALIOMMUDxe/HALIOMMUDxe.efi` **逐字节相同**（147,456 B，sha256 前缀 `44ca4bcf5a9bc739`）；
- 它的 `.data 0xd0b8` 是 InstallMultipleProtocolInterfaces 注册的接口：`+0` = UINT32 版本 `0x00010002`，`+8` 起 17 个函数指针（`0x1720, 0x1970, 0x1a20, 0x1ba0, 0x2870, 0x2db0, 0x3130, 0x31c0, 0x3260, 0x3020, 0x3280, 0x4840, 0x4990, 0x44f0, 0x4770, 0x2cd0` 等），且 `.reloc`（全 Type10 DIR64）**恰好覆盖这 17 个 qword** ⇒ 运行时 `[接口+8]` 必然是代码地址。

而 keys145 实测 `[gIommu+8]` = `"transact"` 的 ASCII，故只可能是：
1. LocateProtocol 其实没成功、`gIommu` 保留/被写成非 HALIOMMU 的值（截断 bug 又把失败当成功）；或
2. 协议数据库里 GUID 54B6D3B4 的 Interface 指针被别的代码改写（堆/协议库污染）；或
3. HALIOMMU 自己安装的接口在运行期被覆写。

FV 内 GUID 生产者扫描（`usb146_guidscan.py`）：`54B6D3B4` 在 FV 内只有 2 处——HALIOMMU 的安装常量 + UsbConfigDxe 的消费常量；其他 Binaries 里出现该 GUID 的 DisplayDxe/UFSDxe/SdccDxe/UCDxe/UsbConfigDxe 都是消费者。⇒ **没有第二个生产者**，所以 keys146 用“强制回退”绕开是当前最稳的工程解；真正根因（谁写坏了接口/协议库）需要 keys147 继续查，方向：HALIOMMU 的 IORT 解析走我们 provider 的 +0x28/+0x30/+0x58/+0x68/+0x70/+0x98/+0xa0/+0xa8，若某槽位返回的 size/值语义不符，可能引发堆越界写并污染协议库。

---

## 5. 上机预期与观察点

预期新增/消失：
- 新增一行：`Failed to open HAL IOMMU protocol Status = (0x0)`（强制回退标记，出现一次属正常）。
- 不再出现 `Synchronous Exception at 0x746361736E617274`。
- IOMMU 映射与拆卸全程跳过（`0x13780/0x13781` 保持 0）；继续走 USB 初始化。
- 应看到 `UsbConfigLibOpenProtocols: PMI version (0x47)`、`usb_repeater_init…`，随后进入 PHY/枚举流程。

重点看哪几行：
1. 有无新的 `Synchronous Exception`（若出现在别处，记下 `ELR/FAR/X8` 与 `(模块+0xRVA)`）。
2. 是否出现 USB 设备枚举/挂载：`[UI] BlockIO devices: N` 的 N 是否变大、`Installed Fat filesystem`、`[FAT16] volume ready`、PC 端是否出现 `K70 LOGDISK` 盘符。
3. 若有 DMA 相关错误/超时（无 SMMU 映射的代价），记录具体字符串。

风险与回退：
- 本改动等于“USB 不做 SMMU/IOMMU 地址翻译”。若平台 SMMU 处于翻译态，USB DMA 可能失败或超时（不会 0x8 崩溃，但功能可能不通）。若真机出现 DMA 故障，回退顺序建议：keys145（保留 HALIOMMU、不强制回退）→ keys143b（无 HALIOMMU + 0x3FA8 加固）→ 再考虑 keys147 做“半程回退”（只在 `[gIommu+8]` 非代码地址时回退，需运行期校验）。
- 强制回退分支不会改动任何全局接口指针以外的状态，**不会影响 PMIC/provider/FAT/菜单**等既有功能。

---

## 6. 验证记录（离线全过）

- `Guid.xref`：HALIOMMU `9A00771F`、ClockDxe `4DB5DEA6`、UsbConfigDxe `CD823A4D`、UsbInitDxe `0A134F0E`、UsbMsdDxe `5AF77F10`、UsbfnDwc3Dxe `94F8A6A7`、UsbDeviceDxe `3299A266`、PmicVerStub `3F6C1D92`、PmicDxe `5776232E`、DtbExtn `5B21E7C4`、LogDisk `9C5E7A31`、Menu `4F7A1C2E`、AcpiTableDxe `9622E42C` 全在；**UFSDxe = 0**。
- `FVMAIN.inf` 放置行：25 UsbfnDwc3Dxe、53 HALIOMMU、57 PmicDxe、69 ClockDxe、89 UsbMsdDxe、90 UsbConfigDxe、91 UsbInitDxe、96 VermeerDtbExtnDxe、101 AcpiTableDxe。
- `FVMAIN.Fv` = 6,160,384 B；UsbConfigDxe FFS @0x3cd120（body 0x3cd138，size 86,170，MZ@payload+0x64）：
  - RVA 0x3FA8 = `02 00 00 14` ✅（keys146 强制回退）
  - RVA 0x53CC = `28 01 00 b4` ✅（keys145 守卫）
  - 与 pristine 的差异只有这两条补丁的 19 个字节。
- DTB：FV 内 1 份，与 `xbl_ufs.dtb` 逐字节相同（57,217 B，sha256 `78c55f2e08136cbfa4f8c2fdfaae66ce67306f7a65395536c4568e92213a3f56`）。
- 构建后 `UsbConfigDxe.patched.efi` 已还原 pristine（0x3FA8=`0802f8b6`、0x53CC=`080540f9`），源码树未被污染。
- 构建日志：`PROGRESS - Success`；LogDisk/FAT 全部检查 OK。
