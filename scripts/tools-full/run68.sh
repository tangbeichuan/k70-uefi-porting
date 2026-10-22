set +e
F=/mnt/d/本地项目-01/_k70port_extract/port-drivers/VermeerDtbExtnDxe/VermeerDtbExtnDxe.c
python3 - "$F" <<'PY'
import sys,io
p=sys.argv[1]; s=io.open(p,encoding='utf-8',errors='replace').read()

# 1) 属性不存在时返回 NOT_FOUND
old = '''  //
  // Not found: keep the zeroes and report success on purpose (see comment above).
  //
  return EFI_SUCCESS;'''
new = '''  //
  // keys68: 属性不存在时必须回报 NOT_FOUND —— 厂商驱动靠这个分支走兜底路径。
  //
  return EFI_NOT_FOUND;'''
assert old in s, 'FdtGetProp tail not found'
s = s.replace(old, new, 1)
print('FdtGetProp -> NOT_FOUND')

# 2) 新增 0x98 槽位（走通用取属性）
if 'EfiApi_Slot98' not in s:
    add = '''STATIC EFI_STATUS
EfiApi_Slot98 (
  IN UINTN  A0,
  IN UINTN  A1,
  IN UINTN  A2,
  IN UINTN  A3
  )
{
  return SlotGetGeneric (0x98, "slot 0x98", A0, A1, A2, A3, 64);
}

'''
    i = s.index('STATIC EFI_STATUS\nEfiApi_Slot40 (')
    s = s[:i] + add + s[i:]

# 3) 接口表里挂上 0x98
s = s.replace('    SetIfcSlot (0xa0, (VOID *)EfiApi_SlotA0);',
              '    SetIfcSlot (0xa0, (VOID *)EfiApi_SlotA0);\n    SetIfcSlot (0x98, (VOID *)EfiApi_Slot98);', 1)
io.open(p,'w',encoding='utf-8').write(s)
print('slot 0x98 wired')
PY
grep -n "Slot98\|return EFI_NOT_FOUND;" "$F" | tail -6
bash /mnt/d/本地项目-01/_k70port_extract/wsl/run_keys67.sh keys68 2>&1 | tail -5
cd /mnt/d/本地项目-01/_k70port_extract/wsl
bash pack_keys.sh "/mnt/d/本地项目-01/_k70port_extract/qemu-fw/SILICIUM_UEFI-keys68.fd" keys68 2>&1 | tail -3