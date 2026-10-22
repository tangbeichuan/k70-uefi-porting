set +e
F=/mnt/d/本地项目-01/_k70port_extract/port-drivers/VermeerDtbExtnDxe/VermeerDtbExtnDxe.c
python3 - "$F" <<'PY'
import sys,io,re
p=sys.argv[1]; s=io.open(p,encoding='utf-8',errors='replace').read()

new_fn = '''STATIC EFI_STATUS
SlotGetByName (
  IN CONST CHAR8  *Tag,
  IN UINTN         A0,
  IN UINTN         A1,
  IN UINTN         A2,
  IN UINTN         A3
  )
{
  UINT32  Off;
  UINT32  Size;

  LogArgs (Tag, A0, A1, A2, A3);

  Off = 0;
  if ((mBlob != NULL) && ((CONST UINT8 *)A0 >= mBlob) && ((CONST UINT8 *)A0 < (mBlob + mBlobSize))) {
    Off = (UINT32)((CONST UINT8 *)A0 - mBlob);
  }

  if ((Off == 0) || (A1 < 0x1000) || (A2 < 0x80000000ULL)) {
    DEBUG ((DEBUG_ERROR, "[DTBEXTN] %a -> rejected (off=0x%x name=0x%lx out=0x%lx)\\n", Tag, Off, (UINT64)A1, (UINT64)A2));
    return EFI_NOT_FOUND;
  }

  Size = ((A3 > 0) && (A3 < 0x200)) ? (UINT32)A3 : 64;

  return FdtGetProp (Off, (CONST CHAR8 *)A1, (VOID *)A2, Size);
}

'''

# 把 Slot40 的实现换成 SlotGetByName
old40 = '''EfiApi_Slot40 (
  IN UINTN  A0,
  IN UINTN  A1,
  IN UINTN  A2,
  IN UINTN  A3
  )
{
  LogArgs ("slot 0x40", A0, A1, A2, A3);
  return EFI_NOT_FOUND;
}'''
new40 = '''EfiApi_Slot40 (
  IN UINTN  A0,
  IN UINTN  A1,
  IN UINTN  A2,
  IN UINTN  A3
  )
{
  return SlotGetByName ("slot 0x40", A0, A1, A2, A3);
}'''
assert old40 in s, 'slot40 body not found'
# 在 Slot40 定义前插入 SlotGetByName
i = s.index('STATIC EFI_STATUS\nEfiApi_Slot40 (')
s = s[:i] + new_fn + s[i:]
s = s.replace(old40, new40, 1)
io.open(p,'w',encoding='utf-8').write(s)
print('slot 0x40 -> tolerant getter')
PY
bash /mnt/d/本地项目-01/_k70port_extract/wsl/run_keys57.sh keys63 2>&1 | tail -4
cd /mnt/d/本地项目-01/_k70port_extract/wsl
bash pack_keys.sh "/mnt/d/本地项目-01/_k70port_extract/qemu-fw/SILICIUM_UEFI-keys63.fd" keys63 2>&1 | tail -3