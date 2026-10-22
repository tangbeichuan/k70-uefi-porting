import pathlib
p = pathlib.Path("/mnt/d/本地项目-01/_k70port_extract/port-drivers/VermeerMenuDxe/VermeerMenuDxe.c")
s = p.read_text(encoding="utf-8")
if "[USB149]" in s:
    print("already patched"); raise SystemExit

helper = r'''
STATIC UINT32
Usb149Rd (
  IN UINTN  A
  )
{
  return *(volatile UINT32 *)A;
}

STATIC VOID
Usb149Wr (
  IN UINTN   A,
  IN UINT32  V
  )
{
  *(volatile UINT32 *)A = V;
}

STATIC VOID
Usb149LateDiag (
  VOID
  )
{
  CONST UINTN  Dwc3 = 0x0A600000;
  UINT32       GsId, Gctl, PhyCfg, Dctl, Dsts, N;
  CHAR16       Buf[220];

  GsId   = Usb149Rd (Dwc3 + 0xC120);
  Gctl   = Usb149Rd (Dwc3 + 0xC110);
  PhyCfg = Usb149Rd (Dwc3 + 0xC200);
  Dctl   = Usb149Rd (Dwc3 + 0xC704);
  Dsts   = Usb149Rd (Dwc3 + 0xC70C);

  UnicodeSPrint (Buf, sizeof (Buf),
                 L"  [USB149] pre : GSNPSID=%08x GCTL=%08x PHYCFG=%08x DCTL=%08x DSTS=%08x",
                 GsId, Gctl, PhyCfg, Dctl, Dsts);
  Say (Buf);

  if (((Dsts & (1u << 22)) != 0) || ((Dctl & (1u << 31)) == 0)) {
    Usb149Wr (Dwc3 + 0xC200, PhyCfg & ~((1u << 6) | (1u << 8)));
    Usb149Wr (Dwc3 + 0xC704, Dctl | (1u << 31));

    for (N = 0; N < 500; N++) {
      Dsts = Usb149Rd (Dwc3 + 0xC70C);
      if ((Dsts & (1u << 22)) == 0) {
        break;
      }

      gBS->Stall (1000);
    }

    UnicodeSPrint (Buf, sizeof (Buf),
                   L"  [USB149] run : polls=%d DCTL=%08x DSTS=%08x hlt22=%d",
                   N, Usb149Rd (Dwc3 + 0xC704), Dsts, (Dsts >> 22) & 1);
    Say (Buf);
  }

  gBS->Stall (200 * 1000);
  Dctl = Usb149Rd (Dwc3 + 0xC704);
  Dsts = Usb149Rd (Dwc3 + 0xC70C);
  UnicodeSPrint (Buf, sizeof (Buf),
                 L"  [USB149] post: DCTL=%08x DSTS=%08x hlt22=%d devspd=%d",
                 Dctl, Dsts, (Dsts >> 22) & 1, (Dsts >> 1) & 0xF);
  Say (Buf);
}

'''

marker = "EFI_STATUS\nEFIAPI\nVermeerMenuDxeEntry ("
i = s.find(marker)
assert i > 0, "entry marker not found"
s = s[:i] + helper + s[i:]

old = '  Say (L"  [MENU102] menu armed, waiting for volume keys");\n  RunMenu ();'
assert old in s, "menu call anchor not found"
new = '  Say (L"  [MENU149] console stays on, GUI skipped");\n  Usb149LateDiag ();\n  Say (L"  [MENU149] diag done - halting for photo (keys88 style)");\n  CpuDeadLoop ();'
s = s.replace(old, new)
p.write_text(s, encoding="utf-8")
print("patched MenuDxe, USB149 present:", "[USB149]" in s)