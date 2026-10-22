import io, sys

P = '/mnt/d/本地项目-01/_k70port_extract/port-drivers/VermeerDtbExtnDxe/VermeerDtbExtnDxe.c'
s = io.open(P, encoding='utf-8', errors='replace').read()

# 1) EfiApi_Unsupported: 记录调用者 LR，用于定位被调用的槽位
old_stub = """EfiApi_Unsupported (
  VOID
  )
{
  return EFI_NOT_FOUND;
}"""
new_stub = """EfiApi_Unsupported (
  VOID
  )
{
  VOID  *Caller;

  Caller = __builtin_return_address (0);
  DEBUG ((
    DEBUG_ERROR,
    "[DTBEXTN] UNSUPPORTED slot called, LR=0x%lx\\n",
    (UINT64)(UINTN)Caller
    ));
  return EFI_NOT_FOUND;
}"""

if 'UNSUPPORTED slot called' not in s:
    assert old_stub in s, 'unsupported stub pattern not found'
    s = s.replace(old_stub, new_stub, 1)
    print('patched EfiApi_Unsupported (LR logging)')
else:
    print('EfiApi_Unsupported already patched')

# 2) EfiApi_GetPropByte: 也加日志（0xa8 槽可能走这里）
old_byte = """  if ((mBlob == NULL) || (Name == NULL)) {
    return EFI_INVALID_PARAMETER;
  }

  return FdtGetProp (NodeToOffset (Node), Name, Out, 1);"""
new_byte = """  EFI_STATUS  Status;

  if ((mBlob == NULL) || (Name == NULL)) {
    return EFI_INVALID_PARAMETER;
  }

  Status = FdtGetProp (NodeToOffset (Node), Name, Out, 1);
  if (mByteCallCount < 8) {
    mByteCallCount++;
    DEBUG ((DEBUG_ERROR, "[DTBEXTN] get prop BYTE %a -> %r\\n", Name, Status));
  }

  return Status;"""

if 'get prop BYTE' not in s:
    assert old_byte in s, 'GetPropByte body pattern not found'
    s = s.replace(old_byte, new_byte, 1)
    # 加计数器定义
    anchor = 'STATIC UINTN  mCallCount'
    if anchor not in s:
        anchor = 'STATIC UINT32  mCallCount'
    assert anchor in s, 'mCallCount definition not found'
    s = s.replace(anchor, 'STATIC UINT32  mByteCallCount = 0;\n' + anchor, 1)
    print('patched EfiApi_GetPropByte (+counter)')
else:
    print('EfiApi_GetPropByte already patched')

io.open(P, 'w', encoding='utf-8').write(s)
print('written', P)
