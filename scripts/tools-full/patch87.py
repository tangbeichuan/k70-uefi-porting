import pathlib, re
p = pathlib.Path('/mnt/d/本地项目-01/_k70port_extract/port-drivers/VermeerKeyProbeDxe/VermeerKeyProbeDxe.c')
s = p.read_text(encoding='utf-8')

# 1) 在 host idle ok 之后插入 run-stop 等待 + 全量清零（照抄 ios-vermeer-lab 的顺序）
anchor = '  UfsPrint ("[UFS71] host idle ok\\n");'
ins = anchor + '''

  //
  // keys87: 照抄 ios-vermeer-lab 的顺序 —— 先停 transfer list，再清 DMA，再接管
  //
  {
    UINT32 StopTries = 0;
    UfsWr (0x60, 0);
    while (((UfsRd (0x60) & 1) != 0) && (StopTries < 1000)) {
      gBS->Stall (1000);
      StopTries++;
    }
    AsciiSPrint (Line, sizeof (Line), "[UFS87] run-stop wait: 60=%08x tries=%d\\n", UfsRd (0x60), (UINT32)StopTries);
    UfsPrint (Line);
    if ((UfsRd (0x60) & 1) != 0) {
      UfsPrint ("[UFS87] transfer list did not stop - abort\\n");
      return;
    }
    ZeroMem ((VOID *)(UINTN)mUfsDmaPa, 0x6000);
    UfsDmaSync ();
    UfsPrint ("[UFS87] dma zeroed (0x6000) + flushed\\n");
  }'''
assert anchor in s
s = s.replace(anchor, ins, 1)

# 2) 门铃前后加寄存器快照，便于判断是不是门铃本身把总线挂死
old = '''  UfsDmaSync ();
  UfsWr (0x58, 1);
  if (!UfsWait (0x58, 1, 0, (Opcode == 0x2a) ? 3000 : 1000)) {
    return 1;
  }'''
new = '''  UfsDmaSync ();
  AsciiSPrint (Line87, sizeof (Line87), "[UFS87] pre-doorbell 58=%08x 3c=%08x is=%08x 60=%08x\\n",
               UfsRd (0x58), UfsRd (0x3C), UfsRd (0x20), UfsRd (0x60));
  UfsPrint (Line87);
  UfsWr (0x58, 1);
  AsciiSPrint (Line87, sizeof (Line87), "[UFS87] doorbell written, 58=%08x\\n", UfsRd (0x58));
  UfsPrint (Line87);
  if (!UfsWait (0x58, 1, 0, (Opcode == 0x2a) ? 3000 : 1000)) {
    AsciiSPrint (Line87, sizeof (Line87), "[UFS87] doorbell timeout 58=%08x 3c=%08x is=%08x\\n",
                 UfsRd (0x58), UfsRd (0x3C), UfsRd (0x20));
    UfsPrint (Line87);
    return 1;
  }'''
assert old in s
s = s.replace(old, new, 1)
s = s.replace('  STATIC UINT8  Tag;', '  STATIC UINT8  Tag;\n  CHAR8         Line87[128];', 1)
p.write_text(s, encoding='utf-8')
print('patched keys87: run-stop + doorbell snapshots')