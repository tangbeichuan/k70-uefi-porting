set +e
F=/mnt/d/本地项目-01/_k70port_extract/port-drivers/VermeerDtbExtnDxe/VermeerDtbExtnDxe.c
python3 - "$F" <<'PY'
import sys,io
p=sys.argv[1]; s=io.open(p,encoding='utf-8',errors='replace').read()

gen = '''STATIC BOOLEAN
IsBlobPtr (
  IN UINTN  A
  )
{
  return ((mBlob != NULL) && ((CONST UINT8 *)A >= mBlob) && ((CONST UINT8 *)A < (mBlob + mBlobSize))) ? TRUE : FALSE;
}

STATIC BOOLEAN
LooksLikeName (
  IN UINTN  A
  )
{
  CONST UINT8  *B;

  if ((A < 0x80000000ULL) || (A >= 0x100000000ULL)) {
    return FALSE;
  }

  B = (CONST UINT8 *)A;
  return ((B[0] >= 0x20) && (B[0] < 0x7F) && (B[1] >= 0x20) && (B[1] < 0x7F) &&
          (B[2] >= 0x20) && (B[2] < 0x7F)) ? TRUE : FALSE;
}

//
// keys64：按"参数在哪个位置"反推 ABI。
// 观察到的事实：名字一定在某个参数里（如 "Signature"、"id"、"smpl-d..."），
// 节点句柄是落在 blob 里的指针，出参缓冲区在 DXE 栈上（0xA75xxxxx ~ 0xA79xxxxx）。
//
STATIC EFI_STATUS
SlotGetGeneric (
  IN CONST CHAR8  *Tag,
  IN UINTN         A0,
  IN UINTN         A1,
  IN UINTN         A2,
  IN UINTN         A3,
  IN UINT32        MaxSize
  )
{
  UINTN       Args[4];
  UINTN       Node;
  UINTN       Name;
  UINTN       Out;
  UINT32      Off;
  UINT32      Size;
  EFI_STATUS  Status;
  UINTN       i;

  LogArgs (Tag, A0, A1, A2, A3);

  Args[0] = A0; Args[1] = A1; Args[2] = A2; Args[3] = A3;
  Node = 0; Name = 0; Out = 0;

  for (i = 0; i < 4; i++) {
    if ((Node == 0) && IsBlobPtr (Args[i])) {
      Node = Args[i];
    }
  }

  for (i = 0; i < 4; i++) {
    if ((Args[i] != Node) && LooksLikeName (Args[i])) {
      Name = Args[i];
      break;
    }
  }

  for (i = 0; i < 4; i++) {
    if ((Args[i] != Node) && (Args[i] != Name) &&
        (Args[i] >= 0xA7500000ULL) && (Args[i] < 0xA7A00000ULL))
    {
      Out = Args[i];
      break;
    }
  }

  if ((Node == 0) || (Name == 0) || (Out == 0)) {
    DEBUG ((DEBUG_ERROR, "[DTBEXTN] %a -> unresolved (node=0x%lx name=0x%lx out=0x%lx)\\n",
            Tag, (UINT64)Node, (UINT64)Name, (UINT64)Out));
    return EFI_NOT_FOUND;
  }

  Off = (UINT32)((CONST UINT8 *)Node - mBlob);
  Size = MaxSize;
  if ((A3 > 0) && (A3 < MaxSize)) {
    Size = (UINT32)A3;
  }

  Status = FdtGetProp (Off, (CONST CHAR8 *)Name, (VOID *)Out, Size);
  DEBUG ((DEBUG_ERROR, "[DTBEXTN] %a -> node=0x%lx name=\\"%a\\" out=0x%lx size=%d : %r\\n",
          Tag, (UINT64)Node, (CONST CHAR8 *)Name, (UINT64)Out, Size, Status));
  return Status;
}

'''

# 在所有 Slot 函数定义前插入
anchor = 'STATIC EFI_STATUS\nEfiApi_Slot40 ('
assert anchor in s, 'slot40 anchor missing'
if 'SlotGetGeneric' not in s:
    s = s.replace(anchor, gen + anchor, 1)
    print('generic getter inserted')

repl = {
 'EfiApi_Slot40': ('"slot 0x40"', '64'),
 'EfiApi_Slot88': ('"slot 0x88"', '64'),
 'EfiApi_Slot90': ('"slot 0x90"', '64'),
 'EfiApi_SlotA0': ('"slot 0xa0"', '64'),
}
import re
for fn,(tag,sz) in repl.items():
    pat = re.compile(r'(STATIC EFI_STATUS\s+' + fn + r' \(\s*\n(?:.*\n)*?\})(\n)', re.M)
    m = pat.search(s)
    if not m:
        print('miss', fn); continue
    body = m.group(1)
    newbody = ('STATIC EFI_STATUS\n'
               + fn + ' (\n'
               '  IN UINTN  A0,\n  IN UINTN  A1,\n  IN UINTN  A2,\n  IN UINTN  A3\n  )\n'
               '{\n'
               '  return SlotGetGeneric (' + tag + ', A0, A1, A2, A3, ' + sz + ');\n}')
    s = s[:m.start(1)] + newbody + s[m.end(1):]
    print('rewired', fn)

io.open(p,'w',encoding='utf-8').write(s)
PY
bash /mnt/d/本地项目-01/_k70port_extract/wsl/run_keys57.sh keys64 2>&1 | tail -6
cd /mnt/d/本地项目-01/_k70port_extract/wsl
bash pack_keys.sh "/mnt/d/本地项目-01/_k70port_extract/qemu-fw/SILICIUM_UEFI-keys64.fd" keys64 2>&1 | tail -3