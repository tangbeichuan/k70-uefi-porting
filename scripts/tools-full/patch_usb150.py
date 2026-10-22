#!/usr/bin/env python3
# keys150: replace lead's keys149 USB149 block in VermeerMenuDxe.c with keys150
# sequence: GUSB2PHYCFG clear SUSPHY/ENBLSLPM/PHYSOFTRST -> GCTL.PRTCAPDIR=2 (device)
#           -> DCTL.RUN_STOP=1 -> stall 300ms -> dump -> CpuDeadLoop
import pathlib, re, sys

p = pathlib.Path("/mnt/d/本地项目-01/_k70port_extract/port-drivers/VermeerMenuDxe/VermeerMenuDxe.c")
s = p.read_text(encoding="utf-8")

if "[USB150]" in s:
    print("patch_usb150: already patched")
    sys.exit(0)

if "[USB149]" not in s:
    print("patch_usb150: FATAL keys149 block not found")
    sys.exit(1)

NEW_BLOCK = r'''STATIC UINT32
Usb150Rd (
  IN UINTN  Address
  )
{
  return *(volatile UINT32 *)Address;
}

STATIC VOID
Usb150Wr (
  IN UINTN   Address,
  IN UINT32  Value
  )
{
  *(volatile UINT32 *)Address = Value;
}

STATIC VOID
Usb150Dump (
  IN CONST CHAR16  *Tag
  )
{
  CONST UINTN  Dwc3 = 0x0A600000;
  UINT32       GsId;
  UINT32       Gctl;
  UINT32       Gsts;
  UINT32       PhyCfg;
  UINT32       PipeCtl;
  UINT32       Dcfg;
  UINT32       Dctl;
  UINT32       Dsts;
  UINT32       PrtCap;
  UINT32       RunStop;
  UINT32       Hlt;
  UINT32       StsB0;
  UINT32       Spd;
  UINT32       Lnk;
  UINT32       SusPhy;
  UINT32       EnblSlpm;
  UINT32       PhyRst;
  CHAR16       Buf[200];

  GsId    = Usb150Rd (Dwc3 + 0xC120);
  Gctl    = Usb150Rd (Dwc3 + 0xC110);
  Gsts    = Usb150Rd (Dwc3 + 0xC118);
  PhyCfg  = Usb150Rd (Dwc3 + 0xC200);
  PipeCtl = Usb150Rd (Dwc3 + 0xC2C0);
  Dcfg    = Usb150Rd (Dwc3 + 0xC700);
  Dctl    = Usb150Rd (Dwc3 + 0xC704);
  Dsts    = Usb150Rd (Dwc3 + 0xC70C);

  PrtCap   = (Gctl >> 12) & 0x3;
  SusPhy   = (PhyCfg >> 6) & 0x1;
  EnblSlpm = (PhyCfg >> 8) & 0x1;
  PhyRst   = (PhyCfg >> 31) & 0x1;
  RunStop  = (Dctl >> 31) & 0x1;
  Hlt      = (Dsts >> 22) & 0x1;
  StsB0    = Gsts & 0x1;
  Spd      = Dsts & 0x7;
  Lnk      = (Dsts >> 18) & 0xF;

  UnicodeSPrint (Buf, sizeof (Buf),
                 L"  [USB150] %s id: GSNPSID=%08x GCTL=%08x GSTS=%08x",
                 Tag, GsId, Gctl, Gsts);
  Say (Buf);
  UnicodeSPrint (Buf, sizeof (Buf),
                 L"  [USB150] %s cfg: PHYCFG=%08x PIPECTL=%08x DCFG=%08x",
                 Tag, PhyCfg, PipeCtl, Dcfg);
  Say (Buf);
  UnicodeSPrint (Buf, sizeof (Buf),
                 L"  [USB150] %s dev: DCTL=%08x DSTS=%08x",
                 Tag, Dctl, Dsts);
  Say (Buf);
  UnicodeSPrint (Buf, sizeof (Buf),
                 L"  [USB150] %s dec: prtcap=%d run=%d hlt22=%d spd=%d lnk=%d",
                 Tag, PrtCap, RunStop, Hlt, Spd, Lnk);
  Say (Buf);
  UnicodeSPrint (Buf, sizeof (Buf),
                 L"  [USB150] %s phy: susphy=%d enblslpm=%d phyrst=%d gsts_b0=%d",
                 Tag, SusPhy, EnblSlpm, PhyRst, StsB0);
  Say (Buf);
}

STATIC VOID
Usb150LateDiag (
  VOID
  )
{
  CONST UINTN  Dwc3    = 0x0A600000;
  CONST UINTN  Scratch = 0x0A6F8800;
  UINT32       PhyCfg;
  UINT32       Gctl;
  UINT32       Dctl;
  UINT32       Hs;
  UINT32       Ss;
  UINT32       Gcc;
  UINT32       N;
  CHAR16       Buf[200];

  Usb150Dump (L"pre ");

  //
  // 1) USB2 PHY: clear SUSPHY(bit6), ENBLSLPM(bit8), PHYSOFTRST(bit31)
  //
  PhyCfg  = Usb150Rd (Dwc3 + 0xC200);
  PhyCfg &= ~((1u << 6) | (1u << 8) | (1u << 31));
  Usb150Wr (Dwc3 + 0xC200, PhyCfg);

  //
  // 2) GCTL.PRTCAPDIR = 2 (device).  1 = host, 2 = device, 3 = OTG.
  //
  Gctl  = Usb150Rd (Dwc3 + 0xC110);
  Gctl &= ~(3u << 12);
  Gctl |= (2u << 12);
  Usb150Wr (Dwc3 + 0xC110, Gctl);
  gBS->Stall (100);

  //
  // 3) DCTL.RUN_STOP = 1, then wait for DSTS.DEVCTRLHLT(bit22) == 0 and settle.
  //
  Dctl  = Usb150Rd (Dwc3 + 0xC704);
  Dctl |= (1u << 31);
  Usb150Wr (Dwc3 + 0xC704, Dctl);

  for (N = 0; N < 300; N++) {
    if ((Usb150Rd (Dwc3 + 0xC70C) & (1u << 22)) == 0) {
      break;
    }

    gBS->Stall (1000);
  }

  gBS->Stall (300 * 1000);

  //
  // 4) VBUS-valid override (idempotent, same bits as DtbExtn early block).
  //
  Hs  = Usb150Rd (Scratch + 0x10);
  Ss  = Usb150Rd (Scratch + 0x30);
  Usb150Wr (Scratch + 0x10, Hs | (1u << 20) | (1u << 28));
  Usb150Wr (Scratch + 0x30, Ss | (1u << 24));
  Hs  = Usb150Rd (Scratch + 0x10);
  Ss  = Usb150Rd (Scratch + 0x30);
  Gcc = Usb150Rd (0x0010F004);

  UnicodeSPrint (Buf, sizeof (Buf),
                 L"  [USB150] vbus: HS=%08x SS=%08x GCC_GDSCR=%08x",
                 Hs, Ss, Gcc);
  Say (Buf);
  UnicodeSPrint (Buf, sizeof (Buf),
                 L"  [USB150] seq: PHYCFG=%08x GCTL=%08x DCTL=%08x polls=%d",
                 Usb150Rd (Dwc3 + 0xC200), Usb150Rd (Dwc3 + 0xC110),
                 Usb150Rd (Dwc3 + 0xC704), N);
  Say (Buf);

  Usb150Dump (L"post");
}

'''

# 1) replace the keys149 helper block (Usb149Rd .. end of Usb149LateDiag)
start_marker = "STATIC UINT32\nUsb149Rd ("
end_marker = "EFI_STATUS\nEFIAPI\nVermeerMenuDxeEntry ("
i = s.find(start_marker)
j = s.find(end_marker)
if i < 0 or j < 0 or j <= i:
    print("patch_usb150: FATAL helper block markers not found i=%d j=%d" % (i, j))
    sys.exit(1)
s = s[:i] + NEW_BLOCK + s[j:]

# 2) replace the call site block
NEW_CALL = (
    '  Say (L"  [MENU150] console stays on, USB150 diag then photo halt");\n'
    '  {\n'
    '    STATIC UINTN  mGuiDisabled150 = 0;\n'
    '\n'
    '    if (mGuiDisabled150 == 0) {\n'
    '      Usb150LateDiag ();\n'
    '    } else {\n'
    '      RunMenu ();\n'
    '    }\n'
    '  }\n'
    '  Say (L"  [MENU150] diag done - halting for photo");\n'
    '  CpuDeadLoop ();\n'
)
call_old = (
    '  Say (L"  [MENU149] console stays on, GUI skipped");\n'
    '  {\n'
    '    STATIC UINTN  mGuiDisabled149 = 0;\n'
    '\n'
    '    if (mGuiDisabled149 == 0) {\n'
    '      Usb149LateDiag ();\n'
    '    } else {\n'
    '      RunMenu ();\n'
    '    }\n'
    '  }\n'
)
if call_old not in s:
    # fall back to a regex spanning anything between the two MENU149 lines
    m = re.search(r'  Say \(L"  \[MENU149\] console stays on, GUI skipped"\);.*?CpuDeadLoop \(\);\n',
                  s, re.S)
    if not m:
        print("patch_usb150: FATAL call site not found")
        sys.exit(1)
    s = s[:m.start()] + NEW_CALL + s[m.end():]
else:
    s = s.replace(call_old, NEW_CALL)

p.write_text(s, encoding="utf-8")
print("patch_usb150: OK  USB150 present:", "[USB150]" in s, " USB149 left:", "[USB149]" in s)
