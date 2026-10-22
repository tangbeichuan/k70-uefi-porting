#!/usr/bin/env python3
"""patch_usb154.py -- keys152 -> keys154 Menu patch.

keys152 的只读诊断读 GCC_GDSCR (0x0010F004) 时崩溃：该地址在 DXE 页表里未映射
（异常 PC = VermeerMenuDxe +0x1C98 正是 `ldr w5,[x8]`, x8=0x0010F004）。

keys154 的 Menu 行为：
  1. [USB150] pre dump（只读 DWC3 区 0x0A600000，映射存在）
  2. [USB154] vbus readonly（只读 QSCRATCH 0x0A6F8800 的 +0x10/+0x30，位于已映射的
     0x0A600000+2MB 区域内）——**不再读 GCC**
  3. GUSB2PHYCFG 清 SUSPHY(bit6)/ENBLSLPM(bit8)/PHYSOFTRST(bit31)，写前读、写后读回校验
  4. DCTL：置 RUN_STOP(bit31)=1（databook：1=run、0=stop；若已是 1 则保持），写后读回
  5. gBS->Stall(50ms) ×2，中间读 DSTS，打印 hlt22/spd/lnk
  6. [USB154] after-run + Usb150Dump("final")，return EFI_SUCCESS（无 CpuDeadLoop）
  7. 不写 QSCRATCH（VBUS 覆盖一律不做）
"""
import pathlib
import sys

P = pathlib.Path("/root/k70/uefi/Platforms/Xiaomi/vermeerPkg/Drivers/VermeerMenuDxe/VermeerMenuDxe.c")
s = P.read_text(encoding="utf-8")

if "Usb154Run" in s:
    print("patch_usb154: already patched (Usb154Run present)")
    sys.exit(0)

if "Usb152Diag" not in s:
    print("patch_usb154: FATAL baseline is not keys152 (Usb152Diag missing)")
    sys.exit(1)

# ---------------------------------------------------------------- 1) Usb150Wr
if "Usb150Wr (" not in s:
    anchor = "STATIC UINT32\nUsb150Rd (\n  IN UINTN  Address\n  )\n{\n  return *(volatile UINT32 *)Address;\n}\n"
    if anchor not in s:
        print("patch_usb154: FATAL Usb150Rd anchor not found")
        sys.exit(1)
    wr = (
        "\nSTATIC VOID\nUsb150Wr (\n  IN UINTN   Address,\n  IN UINT32  Value\n  )\n"
        "{\n  *(volatile UINT32 *)Address = Value;\n}\n"
    )
    s = s.replace(anchor, anchor + wr, 1)

# ------------------------------------------------------------- 2) Usb154Run
i0 = s.index("STATIC VOID\nUsb152Diag (")
i1 = s.index("EFI_STATUS\nEFIAPI\nVermeerMenuDxeEntry (")
newfn = r'''STATIC VOID
Usb154Run (
  VOID
  )
{
  CONST UINTN  Dwc3    = 0x0A600000;
  CONST UINTN  Scratch = 0x0A6F8800;
  UINT32       PhyCfg;
  UINT32       PhyCfgWant;
  UINT32       Dctl;
  UINT32       Dsts;
  UINT32       Hs;
  UINT32       Ss;
  UINT32       N;
  CHAR16       Buf[200];

  //
  // 0) read-only status (DWC3/QSCRATCH both inside the mapped USB window).
  //    NOTE: never read GCC (0x0010F004) here - it is NOT mapped in DXE and a
  //    read faults (keys152 crash at Menu +0x1C98).  Never write QSCRATCH.
  //
  Hs = Usb150Rd (Scratch + 0x10);
  Ss = Usb150Rd (Scratch + 0x30);
  UnicodeSPrint (Buf, sizeof (Buf), L"  [USB154] vbus readonly: HS=%08x SS=%08x", Hs, Ss);
  Say (Buf);

  //
  // 1) GUSB2PHYCFG: clear SUSPHY(bit6), ENBLSLPM(bit8), PHYSOFTRST(bit31);
  //    keep all other bits.  Read-modify-write with read-back verification.
  //
  PhyCfg     = Usb150Rd (Dwc3 + 0xC200);
  PhyCfgWant = PhyCfg & ~((1u << 6) | (1u << 8) | (1u << 31));
  Usb150Wr (Dwc3 + 0xC200, PhyCfgWant);
  UnicodeSPrint (Buf, sizeof (Buf),
                 L"  [USB154] phycfg: before=%08x want=%08x after=%08x ok=%d",
                 PhyCfg, PhyCfgWant, Usb150Rd (Dwc3 + 0xC200),
                 (Usb150Rd (Dwc3 + 0xC200) == PhyCfgWant) ? 1 : 0);
  Say (Buf);

  //
  // 2) DCTL: RUN_STOP(bit31) = 1 starts the device controller (databook:
  //    1 = run, 0 = stop).  Read-back verified.
  //
  Dctl = Usb150Rd (Dwc3 + 0xC704);
  Usb150Wr (Dwc3 + 0xC704, Dctl | (1u << 31));
  UnicodeSPrint (Buf, sizeof (Buf),
                 L"  [USB154] dctl: before=%08x after=%08x run=%d",
                 Dctl, Usb150Rd (Dwc3 + 0xC704),
                 (Usb150Rd (Dwc3 + 0xC704) >> 31) & 1);
  Say (Buf);

  //
  // 3) two 50 ms stalls, DSTS read in between.
  //
  for (N = 0; N < 2; N++) {
    gBS->Stall (50 * 1000);
    Dsts = Usb150Rd (Dwc3 + 0xC70C);
    UnicodeSPrint (Buf, sizeof (Buf),
                   L"  [USB154] after-run[%d]: DSTS=%08x hlt22=%d spd=%d lnk=%d",
                   N, Dsts, (Dsts >> 22) & 1, Dsts & 7, (Dsts >> 18) & 0xF);
    Say (Buf);
  }

  Usb150Dump (L"final");
  Say (L"  [USB154] after-run: done, returning to BDS");
}

'''
s = s[:i0] + newfn + s[i1:]

# ------------------------------------------------------------- 3) entry tail
old_tail_start = '  Say (L"  [MENU152] minimal menu: read-only diag, no writes, returning to BDS");'
old_tail_end = '  Say (L"  [MENU152] diag done - no CpuDeadLoop, returning");'
if old_tail_start not in s or old_tail_end not in s:
    print("patch_usb154: FATAL entry tail anchors not found")
    sys.exit(1)
a = s.index(old_tail_start)
b = s.index(old_tail_end) + len(old_tail_end)
new_tail = '''  Say (L"  [MENU154] USB device-mode bring-up: pre-dump, PHYCFG/DCTL writes, no QSCRATCH");
  {
    STATIC UINTN  mGuiDisabled154 = 0;

    if (mGuiDisabled154 == 0) {
      Usb154Run ();
    } else {
      RunMenu ();
    }
  }
'''
s = s[:a] + new_tail + s[b:]

P.write_text(s, encoding="utf-8")
print("PATCH_USB154 OK: Usb154Run installed, GCC read removed, entry tail = MENU154")
