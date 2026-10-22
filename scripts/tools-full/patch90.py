import pathlib
p = pathlib.Path('/mnt/d/本地项目-01/_k70port_extract/port-drivers/VermeerKeyProbeDxe/VermeerKeyProbeDxe.c')
s = p.read_text(encoding='utf-8')

# --- 1) GCC 时钟/电源状态只读诊断（照 UniXNU NativeUfs 的做法：只读不写） ---
if 'UFS90' not in s:
    anchor = '  UfsPrint ("[UFS71] host idle ok\\n");'
    ins = anchor + '''

  //
  // keys90: 照 UniXNU NativeUfs 的做法，只读 GCC 里 UFS 的电源/时钟状态。
  // GDSCR bit31 = PWR_ON；CBCR bit31 = CLK_OFF。写入不做（语义未验证）。
  //
  if (gDS != NULL) {
    EFI_STATUS  GccSt;
    GccSt = gDS->AddMemorySpace (EfiGcdMemoryTypeMemoryMappedIo, 0x00100000ULL, 0x00100000ULL,
                                 EFI_MEMORY_UC | EFI_MEMORY_RUNTIME);
    AsciiSPrint (Line, sizeof (Line), "[UFS90] gcc map -> %r\\n", GccSt);
    UfsPrint (Line);
    if (!EFI_ERROR (GccSt)) {
      gDS->SetMemorySpaceAttributes (0x00100000ULL, 0x00100000ULL, EFI_MEMORY_UC);
      AsciiSPrint (Line, sizeof (Line),
                   "[UFS90] gcc gdscr=%08x mem_phy_gdscr=%08x axi=%08x ahb=%08x unipro=%08x\\n",
                   UfsRdAddr (0x00100000ULL + 0x77004), UfsRdAddr (0x00100000ULL + 0x9e000),
                   UfsRdAddr (0x00100000ULL + 0x77018), UfsRdAddr (0x00100000ULL + 0x77024),
                   UfsRdAddr (0x00100000ULL + 0x77068));
      UfsPrint (Line);
      AsciiSPrint (Line, sizeof (Line),
                   "[UFS90] gcc tx0=%08x rx0=%08x aux=%08x rx1=%08x aggre=%08x\\n",
                   UfsRdAddr (0x00100000ULL + 0x77028), UfsRdAddr (0x00100000ULL + 0x7702c),
                   UfsRdAddr (0x00100000ULL + 0x770b0), UfsRdAddr (0x00100000ULL + 0x770cc),
                   UfsRdAddr (0x00100000ULL + 0x770e4));
      UfsPrint (Line);
    }
  }'''
    assert anchor in s
    s = s.replace(anchor, ins, 1)

    # 通用按绝对地址读 32 位
    helper = '''

STATIC
UINT32
UfsRdAddr (
  IN UINT64  Addr
  )
{
  return *(volatile UINT32 *)(UINTN)Addr;
}
'''
    s = s.replace('STATIC\nINT32\nUfsUicCmd (', helper + '\nSTATIC\nINT32\nUfsUicCmd (', 1)

# --- 2) 完成判定改用 OCS（照 UniXNU TransferPoll：门铃清零不等于命令被接受） ---
old = '''  if (!UfsWait (0x58, 1, 0, (Opcode == 0x2a) ? 3000 : 1000)) {
    AsciiSPrint (Line87, sizeof (Line87), "[UFS87] doorbell timeout 58=%08x 3c=%08x is=%08x\\n",
                 UfsRd (0x58), UfsRd (0x3C), UfsRd (0x20));
    UfsPrint (Line87);
    return 1;
  }'''
new = '''  {
    UINTN  Poll;
    UINT32 OcsNow;
    for (Poll = 0; Poll < 2000; Poll++) {
      UINT32 Is = UfsRd (0x20);
      if ((Is & 0x00071880U) != 0) {
        AsciiSPrint (Line87, sizeof (Line87), "[UFS90] fatal IS=%08x 58=%08x\\n", Is, UfsRd (0x58));
        UfsPrint (Line87);
        return 2;
      }
      OcsNow = (UINT32)(Utrd[2] & 0xFF);
      if (((UfsRd (0x58) & 1) == 0) && (OcsNow != 15)) {
        break;
      }
      gBS->Stall (1000);
    }
    AsciiSPrint (Line87, sizeof (Line87), "[UFS90] poll done: polls=%d 58=%08x is=%08x ocs=%02x\\n",
                 (UINT32)Poll, UfsRd (0x58), UfsRd (0x20), (UINT32)(Utrd[2] & 0xFF));
    UfsPrint (Line87);
    if (Poll >= 2000) {
      AsciiSPrint (Line87, sizeof (Line87), "[UFS90] doorbell timeout 58=%08x 3c=%08x is=%08x\\n",
                   UfsRd (0x58), UfsRd (0x3C), UfsRd (0x20));
      UfsPrint (Line87);
      return 1;
    }
  }'''
assert old in s
s = s.replace(old, new, 1)
p.write_text(s, encoding='utf-8')
print('patched keys90: gcc readback + OCS-based polling')