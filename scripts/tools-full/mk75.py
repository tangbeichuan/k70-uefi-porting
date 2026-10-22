import io
p='/mnt/d/本地项目-01/_k70port_extract/port-drivers/VermeerKeyProbeDxe/VermeerKeyProbeDxe.c'
s=io.open(p,encoding='utf-8',errors='replace').read()

# 关闭 keys74 的 dump-only
s=s.replace('#define UFS74_DUMPONLY 1','#define UFS41_DUMPONLY_OFF 1',1)

if 'UFS75_UIC' in s:
    print('already'); raise SystemExit

# 1) 在 UfsScsi 之前插入 UIC 辅助函数
anchor='''//
// 一条 UPIU：opcode 0 = TUR, 0x28 = READ(10), 0x25 = READ CAPACITY(10)
//'''
uic='''//
// UFS75: UIC 命令（纯寄存器，无 DMA）—— 用来判断链路/设备是否还活着
//
STATIC
INT32
UfsUicCmd (
  IN  UINT32  Opcode,
  IN  UINT32  Arg1,
  IN  UINT32  Arg2,
  IN  UINT32  Arg3,
  OUT UINT32  *Res,
  OUT UINT32  *OutArg3
  )
{
  UINTN  i;

  UfsWr (0x94, Arg1);
  UfsWr (0x98, Arg2);
  UfsWr (0x9C, Arg3);
  UfsWr (0x90, (Opcode << 16) | 1);
  for (i = 0; i < 200; i++) {
    if ((UfsRd (0x90) & 1) == 0) {
      break;
    }
    gBS->Stall (1000);
  }
  *Res     = UfsRd (0x98);
  *OutArg3 = UfsRd (0x9C);
  return (i >= 200) ? 1 : 0;
}

''' + anchor
assert anchor in s
s=s.replace(anchor,uic,1)

# 2) 在"接管 transfer list"之前插入 UIC 测试并 return
anchor2='''  //
  // 接管 transfer list
  //'''
block='''  //
  // UFS75: 只做 UIC（不发门铃）
  //
  {
    UINT32  Res;
    UINT32  Out3;
    INT32   Rc;

    AsciiSPrint (Line, sizeof (Line), "[UFS75] before: IS=%08x HCS=%08x IE=%08x\\n",
                 UfsRd (0x20), UfsRd (0x30), UfsRd (0x24));
    UfsPrint (Line);

    Rc = UfsUicCmd (0x01, 0x00, 0, 0, &Res, &Out3);
    AsciiSPrint (Line, sizeof (Line), "[UFS75] DME_GET(0x00) rc=%d res=%08x arg3=%08x\\n", (UINT32)Rc, Res, Out3);
    UfsPrint (Line);

    Rc = UfsUicCmd (0x01, 0x02, 0, 0, &Res, &Out3);
    AsciiSPrint (Line, sizeof (Line), "[UFS75] DME_GET(0x02) rc=%d res=%08x arg3=%08x\\n", (UINT32)Rc, Res, Out3);
    UfsPrint (Line);

    Rc = UfsUicCmd (0x01, 0x04, 0, 0, &Res, &Out3);
    AsciiSPrint (Line, sizeof (Line), "[UFS75] DME_GET(0x04) rc=%d res=%08x arg3=%08x\\n", (UINT32)Rc, Res, Out3);
    UfsPrint (Line);

    Rc = UfsUicCmd (0x04, 0, 0, 0, &Res, &Out3);
    AsciiSPrint (Line, sizeof (Line), "[UFS75] LINK_STARTUP rc=%d res=%08x\\n", (UINT32)Rc, Res);
    UfsPrint (Line);

    AsciiSPrint (Line, sizeof (Line), "[UFS75] after: IS=%08x HCS=%08x UECPA=%08x\\n",
                 UfsRd (0x20), UfsRd (0x30), UfsRd (0x38));
    UfsPrint (Line);
    UfsPrint ("[UFS75] UIC DONE - no doorbell sent, power-cycle safe\\n");
    return;
  }

''' + anchor2
assert anchor2 in s
s=s.replace(anchor2,block,1)
io.open(p,'w',encoding='utf-8').write(s)
print('keys75 uic block inserted')