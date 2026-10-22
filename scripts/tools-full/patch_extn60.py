import io, re

P = '/mnt/d/本地项目-01/_k70port_extract/port-drivers/VermeerDtbExtnDxe/VermeerDtbExtnDxe.c'
s = io.open(P, encoding='utf-8', errors='replace').read()

helper = """
//
// keys60: 诊断辅助 —— 把 4 个入参都打出来，并把落在 blob 内的指针按字符串/字节解释。
//
STATIC VOID
LogArgs (
  IN CONST CHAR8  *Tag,
  IN UINTN         A0,
  IN UINTN         A1,
  IN UINTN         A2,
  IN UINTN         A3
  )
{
  DEBUG ((DEBUG_ERROR, "[DTBEXTN] %a args: %lx %lx %lx %lx\\n", Tag, (UINT64)A0, (UINT64)A1, (UINT64)A2, (UINT64)A3));

  if ((mBlob != NULL) && (A1 >= (UINTN)mBlob) && (A1 < (UINTN)mBlob + mBlobSize)) {
    DEBUG ((DEBUG_ERROR, "[DTBEXTN]   arg1 -> \\"%a\\"\\n", (CONST CHAR8 *)A1));
  }

  if ((mBlob != NULL) && (A2 >= (UINTN)mBlob) && (A2 < (UINTN)mBlob + mBlobSize)) {
    DEBUG ((DEBUG_ERROR, "[DTBEXTN]   arg2 -> \\"%a\\"\\n", (CONST CHAR8 *)A2));
  }
}

STATIC EFI_STATUS
EfiApi_Slot40 (
  IN UINTN  A0,
  IN UINTN  A1,
  IN UINTN  A2,
  IN UINTN  A3
  )
{
  LogArgs ("slot 0x40", A0, A1, A2, A3);
  return EFI_NOT_FOUND;
}

STATIC EFI_STATUS
EfiApi_Slot88 (
  IN UINTN  A0,
  IN UINTN  A1,
  IN UINTN  A2,
  IN UINTN  A3
  )
{
  LogArgs ("slot 0x88", A0, A1, A2, A3);
  return EFI_NOT_FOUND;
}

STATIC EFI_STATUS
EfiApi_Slot90 (
  IN UINTN  A0,
  IN UINTN  A1,
  IN UINTN  A2,
  IN UINTN  A3
  )
{
  LogArgs ("slot 0x90", A0, A1, A2, A3);
  return EFI_NOT_FOUND;
}

STATIC EFI_STATUS
EfiApi_SlotA0 (
  IN UINTN  A0,
  IN UINTN  A1,
  IN UINTN  A2,
  IN UINTN  A3
  )
{
  LogArgs ("slot 0xa0", A0, A1, A2, A3);
  return EFI_NOT_FOUND;
}

STATIC EFI_STATUS
EfiApi_SlotA8 (
  IN UINTN  A0,
  IN UINTN  A1,
  IN UINTN  A2,
  IN UINTN  A3
  )
{
  LogArgs ("slot 0xa8", A0, A1, A2, A3);
  return EFI_NOT_FOUND;
}

"""

anchor = "//\n// keys59: 每个未实现槽位一个独立函数"
assert anchor in s, 'keys59 anchor missing'
if 'keys60: 诊断辅助' not in s:
    s = s.replace(anchor, helper + anchor, 1)
    print('helper + slot fns inserted')

# 覆盖四个槽位的实现
pairs = [
    ("SetIfcSlot (0x40,", "EfiApi_Slot40"),
    ("SetIfcSlot (0x88,", "EfiApi_Slot88"),
    ("SetIfcSlot (0x90,", "EfiApi_Slot90"),
    ("SetIfcSlot (0xa0,", "EfiApi_SlotA0"),
    ("SetIfcSlot (0xa8,", "EfiApi_SlotA8"),
]
for prefix, fn in pairs:
    if prefix in s:
        # 找到整行并替换函数名
        i = s.index(prefix)
        j = s.index(');', i) + 2
        line = s[i:j]
        newline = re.sub(r'\(VOID \*\)\w+', '(VOID *)' + fn, line)
        s = s[:i] + newline + s[j:]
        print('slot mapped:', prefix, '->', fn)

io.open(P, 'w', encoding='utf-8').write(s)
print('written')
