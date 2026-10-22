# keys162 报告 — 只读 DWC3 设备事件追踪（不做任何 EP0 传输）

基线：keys161（PHY 保活、**绝不写 DCTL.CSFTRST**）。
交付物（`D:\本地项目-01\K70-UEFI-build\`）：

| 文件 | 大小 | sha256 |
|---|---|---|
| `Mu-vermeer-keys162.img` = `K70-keys162-EVTRACE-ONLY.img` = `-fat.img` = `-marker.img` | 1,798,144 B | `c3204d4763c1ad661ca83a7db2663c2b2f34b5515ea6cf016e2d09df6e02f99a` |
| `Mu-vermeer-keys162-v4.img`（备用封装） | — | `55fbca11c5b6b795c1e4f8acaf45cac965b248c9d95a665e0b617060f3601c4b` |
| `_k70port_extract/qemu-fw/SILICIUM_UEFI-keys162.fd` | 4,194,304 B | `6395c711f8aab94205427ab1fde5790b692c5401e0ecd052c5eb8059bb3a06ec` |

回退：keys161 img `ccf2cceb43734c9a0e1b02e832fa46ef8a03b3f38c4fd26701e6d3224656dbb9` / FD `1549e1dfbb0ccd46d62396bd1c29009b41fbe1b4435677263de07856af8dfb2c`。

## 1. 这一版做了什么（相对 keys161）

**只改 VermeerMenuDxe 一个模块**（离线验证：90 模块、0 增删、唯一变化 Menu 34,366 → 30,270 B；
SEC/PEI 65440 B sha `cfcfca5e…` 与 keys161 逐字节相同；内嵌 DTB `71da2503…` 相同、808,716 B）。

- **删掉全部 EP0 逻辑**：没有 `SETEPCONFIG`、`DEPSTARTCFG`、`SETTRANSFRESOURCE`、`STARTTRANSFER`、
  没有 SETUP/STATUS TRB、没有描述符表、没有任何 `0x0A60C800+n*0x10`（DEPCMD）访问
  （反汇编统计 DEPCMD 窗口访问 = 0；`0x40000000` 立即数只出现在无关 UI 的 `and x0,x0,#0x40000000`）。
- 只做 5 步：
  1. `AllocatePages(4)` 拿 4 KiB DMA 页作事件环，`ZeroMem`；
  2. `GUSB2PHYCFG &= ~((1<<8)|(1<<6))`（清 ENBLSLPM / SUSPHY，与 keys161 相同）→ `Stall(20 ms)`；
  3. `GEVNTADRLO/HI = 事件环物理地址`、`GEVNTSIZ = 0x1000`（**bit31=0**）、`GEVNTCOUNT = 读回值&0xffff`（清零）；
  4. `DCFG &= ~(7 | (0x7f<<3))`（HS / 地址 0）、`DEVTEN = 0x7`；
  5. `DCTL` 只操作 `RUN_STOP(bit31)`：若 `DSTS.DEVCTRLHLT(bit22)==1` 则 RUN_STOP=0 → Stall 1 ms →
     RUN_STOP=1 → 轮询 ≤200×1 ms，最多重试 3 轮。**全程不碰 bit30/CSFTRST**。
- 常驻循环（本版故意不回 BDS，方便看屏）：
  - 每 1 ms 读 `GEVNTCOUNT`；非 0 时 `dc civac` 失效事件环缓存 → 逐个 4 B 读出 → **原样**打印
    `[USB162] evt raw=%08x off=%x`（只打前 8 条，不解析）→ 把**已消费字节数**写回 `GEVNTCOUNT`；
  - 每 1000 tick 打 `[USB162] poll: cnt=%08x DSTS=%08x DCTL=%08x consumed=%u`，
    值变化时追加 `regs: GCTL/PHYCFG/DEVTEN/SIZ` 与 `regs2: DCFG/GEVNTADR/evt_pos`；
  - 每 5000 tick 打 `[USB162] alive`；按任意键退出常驻循环 → `RunMenu()`；
  - bring-up 结束时打一行
    `[USB162] bringup done: hlt22=%d phycfg_bit6=%d spd=%u GSNPSID=%08x`。

## 2. GEVNTCOUNT 写回语义（lead 重点核对项）— 已按“字节数”实现

**结论：Linux 的实现就是写“本次消费的字节数”，不是条数、也不是 0。**
`_refs/ios-vermeer-lab/xnu/patches/0073-sweet-usb-device-ep0.patch`（同一 DWC3 IP 上跑通枚举的参考实现）原文：

```c
uint32_t count = dwc_rd(GEVNTCOUNT) & 0xffff;
if (count) {
    ud_sync(UD_EVT, UD_EVT_SIZE);
    for (uint32_t done = 0; done < count; done += 4) {   /* count 是字节数 */
        uint32_t ev = *(volatile uint32_t *)(ud.dma + UD_EVT + ud.evt_pos);
        ud.evt_pos = (ud.evt_pos + 4) % UD_EVT_SIZE;
        ud_event(ev);
    }
    dwc_wr(GEVNTCOUNT, count);      /* 写回已消费字节数 */
}
```

keys162 的实现（`Usb162Poll`）：`Chunk = GEVNTCOUNT & ~3`（截到 4 B 边界，上限 0x1000），
读完 `Chunk` 字节后 `Usb162Wr(GEVNTCOUNT, Chunk)`，并把 `consumed_bytes` 累加后打印在每秒 poll 行。
反汇编证据（keys162 Menu，`Usb162Poll` 内联在常驻循环里）：

```
1e80: 121e3509  and  w9, w8, #0xfffc        ; Chunk = Count & ~3
1e84: 72140d1f  tst  w8, #0xf000            ; >0xFFF ?
1e90: 1a880139  csel w25, w9, w8(#0x1000), eq
...   (每 4 B 取一个 ev, pos = (pos+4)&0xfff, 前 8 条打印)
1edc: b9000399  str  w25, [x28]             ; x28 = 0x0A60C40C (GEVNTCOUNT) ← 写回“字节数”
1ee8: ...        ldr/add/str                ; consumed_bytes += Chunk
```

（另有 `1c80: mov w28,#0xc40c; 1c90: movk w28,#0xa60,lsl#16` ⇒ x28 = 0x0A60C40C，正是 GEVNTCOUNT。）

**GEVNTSIZ bit31 复核**：vendor `UsbfnDwc3Dxe.efi` 0x8bdc–0x8c40 写 GEVNTSIZ 时，
值是 `orr w9,w20,#0x80000000` 与裸 size 经 `csel` 二选一（依据 `tst w21,#0xff` 是否拿到中断资源）
⇒ **bit31 = 事件中断屏蔽位（1=屏蔽中断，仍需轮询），不是事件使能**。
keys162 用 `GEVNTSIZ=0x1000`（bit31=0，不屏蔽，但我们只用轮询、不用中断），与 lead 要求在数值上一致。

## 3. SETUP 的 DWC3 事件类型（lead 问题）— 参考实现可证

参考实现（同一 DWC3 IP，已跑通 PC 枚举）`ud_event()` 的解析：

```c
if (ev & 1) {                       /* bit0=1：设备类事件 */
    uint32_t type = (ev >> 8) & 0xf;   /* bits[11:8] */
    if (type == 0) { disconnect }
    else if (type == 1) { USB reset }
    else if (type == 2) { connect done }
    return;
}
/* bit0=0：端点事件 */
unsigned ep     = (ev >> 1) & 0x1f;   /* bits[5:1]  端点号 */
unsigned type   = (ev >> 6) & 0xf;    /* bits[9:6]  1=XferComplete 3=XferNotReady */
unsigned status = (ev >> 12) & 0xf;   /* bits[15:12] */
if (type == 1) { /* XferComplete: SETUP 完成 / DATA 完成 / STATUS 完成 */ }
if (type == 3 && status == 2) { /* XferNotReady + control status phase */ }
```

⇒ **SETUP 包本身是按 `XferComplete`(type=1) 在 EP0-OUT 上被报告的；`XferNotReady`(type=3,status=2)
只用于“控制传输的状态阶段”启动时机**。也就是说 lead 记的“SETUP=XferNotReady(type=3,status=2)”
不完全对：keys161 如果我们只在 type==3 时才处理，就会漏掉真正的 SETUP 完成事件。
（把 this 与 raw 事件对照即可确认：上机后看 `evt raw` 的 bit0 / bits[9:6] / bits[15:12]。）

### `evt raw` 位域速查表（拿到屏上 raw 后按下表反解）

| 位 | 含义（参考实现口径） |
|---|---|
| bit0 | 1 = 设备类事件（reset/connect/disconnect）；0 = 端点事件 |
| 设备类：bits[11:8] | 0=disconnect、1=USB reset、2=connect done |
| 端点类：bits[5:1] | 端点号（EP0=0，EP0-IN 可能报 1） |
| 端点类：bits[9:6] | 事件类型：1=XferComplete、3=XferNotReady |
| 端点类：bits[15:12] | status：0=正常、2=控制状态阶段（配 XferNotReady）、其它=错误码 |
| bits[27:16] | event parameters（XferNotReady 时含 phase 等） |

> 说明：Linux `dwc3.h` 的 union 里设备类事件另有 `device_event`(bits[7:1]) 字段，与上表的
> “type bits[11:8]”是两套并存口径；本表采用**在同一硬件族跑通枚举的参考实现**的口径，
> raw 打出来后两种口径一起对照即可定案。

## 4. 上机预期 / 判读

| 现象 | 含义 | 下一步 |
|---|---|---|
| 屏上出现 `[USB162] evt raw=…`（至少 connect done 0x…、可能的 USB reset） | 事件环工作正常，设备已被 host 复位/连接 | keys163 按上表实现 EP0（SETUP=XferComplete type=1） |
| 设备**不再复位**、主机仍 `VID_0000&PID_0002` | 正如预期：我们不碰 EP0，没人回描述符 | 同上 |
| 设备仍然一被枚举就复位/回 fastboot | 说明复位不是我们 EP0 代码引起的（事件环/PHY/RUN 保活本身有问题） | 把 poll 行的 DSTS/DCTL/consumed 拍照给 lead，查 hlt22/speed/linkst 变化时刻 |
| 完全没有 evt raw、poll 行 cnt 恒 0 | 事件没进来（或 DEVTEN/DCFG 配置不对、GEVNTADR 未生效） | 用 regs/regs2 行核对 GEVNTADR/SIZ/DEVTEN/DCFG 是否为我们写入的值 |

## 5. 离线验证摘要（`_tools/verify162.py` → RESULT: PASS）

- FD 4,194,304 B sha `6395c711…`；outer FFS 2 个（SEC/PEI body 与 keys161 相同 sha `cfcfca5e…`，GCC 串 0）；
- inner FVMAIN 6,168,584 B，90 模块，0 增删，**唯一变化 VermeerMenuDxe**（34,366 → 30,270 B）；
- Menu EFI 30,208 B sha `735340fb…`，UTF-16 串：MENU162×2、USB162×9、`evt raw`×1、`poll: cnt`×1、
  `consumed`×1、`bringup done`×1；`CpuDeadLoop`/`Usb150Wr`/`dep n=` 均 0；
- 反汇编：DEPCMD 窗口访问 0；GEVNT/DCTL/DEVTEN/PHYCFG 访问存在；`0x40000000` 仅无关 UI `and`；
- 容器：page 2048、kernel 1,792,848 B = gzip(192 B shim + FD 4,194,304 B)，解压 4,194,496 B、
  `fd_in_img==FD` True；尾部 DTB 808,716 B sha `71da250370a977…` 与所有前版相同。

## 6. 工具

- `_tools/patch_usb162.py`：pristine keys149 Menu → keys162（幂等锚 `[MENU162]`）；
- `_tools/run162.sh`：由 build_keys161.sh sed 出道 keys162 血缘、替换菜单补丁、构建+打包+校验；
- `_tools/verify162.py`：上述离线验证；`_tools/k162_dis*.sh`：反汇编取证；
- 日志：`_tools/b162_probe.log`、`b162_wrap.log`、`b162_verify.log`、`k162_dis*.log`。

回退顺序：keys161（`ccf2cceb…`）→ keys161b（`8c6095d4…`）→ keys160（`aa7d64e8…`）。
