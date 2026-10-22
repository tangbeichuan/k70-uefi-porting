set +e
F=/mnt/d/本地项目-01/_k70port_extract/port-drivers/VermeerDtbExtnDxe/VermeerDtbExtnDxe.c
python3 - "$F" <<'PY'
import sys,io,re
p=sys.argv[1]; s=io.open(p,encoding='utf-8',errors='replace').read()

# 1) 去重表
if 'mSeenKey' not in s:
    anchor='STATIC UINTN        mLastNode;'
    s=s.replace(anchor, anchor+'\nSTATIC UINTN        mSeenKey[32];\nSTATIC UINT32       mSeenCount;', 1)

# 2) SlotGetGeneric 增加 SlotId 参数 + 去重
s = s.replace(
'''STATIC EFI_STATUS
SlotGetGeneric (
  IN CONST CHAR8  *Tag,''',
'''STATIC BOOLEAN
SeenBefore (
  IN UINT32  SlotId,
  IN UINTN   Name
  )
{
  UINT32  i;
  UINTN   Key;

  Key = ((UINTN)SlotId << 40) ^ (Name & 0xFFFFFFFFFFULL);

  for (i = 0; i < mSeenCount; i++) {
    if (mSeenKey[i] == Key) {
      return TRUE;
    }
  }

  if (mSeenCount < 32) {
    mSeenKey[mSeenCount++] = Key;
  }

  return FALSE;
}

STATIC EFI_STATUS
SlotGetGeneric (
  IN UINT32        SlotId,
  IN CONST CHAR8  *Tag,''', 1)

# 3) 日志去重
s = s.replace('''  LogArgs (Tag, A0, A1, A2, A3);

  Args[0] = A0;''','''  Quiet = SeenBefore (SlotId, A1);
  if (!Quiet) {
    LogArgs (Tag, A0, A1, A2, A3);
  }

  Args[0] = A0;''',1)

s = s.replace('''  UINTN       i;

  LogArgs''','''  UINTN       i;
  BOOLEAN     Quiet;

  LogArgs''',1)

# 4) 内部调试行只在首次打印
s = s.replace('''  DEBUG ((DEBUG_ERROR, "[DTBEXTN] %a -> node=0x%lx name=\\"%a\\" out=0x%lx size=%d : %r\\n",
          Tag, (UINT64)Node, (CONST CHAR8 *)Name, (UINT64)Out, Size, Status));''',
'''  if (!Quiet) {
    DEBUG ((DEBUG_ERROR, "[DTBEXTN] %a -> node=0x%lx name=\\"%a\\" out=0x%lx size=%d : %r\\n",
            Tag, (UINT64)Node, (CONST CHAR8 *)Name, (UINT64)Out, Size, Status));
  }''',1)

# 5) 调用点补 SlotId
for fn, sid in [('EfiApi_Slot40','0x40'),('EfiApi_Slot88','0x88'),('EfiApi_Slot90','0x90'),('EfiApi_SlotA0','0xa0')]:
    s = s.replace('return SlotGetGeneric ("slot ' + sid + '"', 'return SlotGetGeneric (' + sid + ', "slot ' + sid + '"', 1)

io.open(p,'w',encoding='utf-8').write(s)
print('dedup added')
PY
grep -n "SeenBefore\|Quiet" "$F" | head
bash /mnt/d/本地项目-01/_k70port_extract/wsl/run_keys57.sh keys66 2>&1 | tail -4
cd /mnt/d/本地项目-01/_k70port_extract/wsl
bash pack_keys.sh "/mnt/d/本地项目-01/_k70port_extract/qemu-fw/SILICIUM_UEFI-keys66.fd" keys66 2>&1 | tail -3